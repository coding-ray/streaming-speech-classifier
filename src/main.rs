use rust_bert::{
    deberta::{
        DebertaConfig, DebertaConfigResources, DebertaForSequenceClassification,
        DebertaMergesResources, DebertaModelResources, DebertaVocabResources,
    },
    resources::{load_weights, RemoteResource, ResourceProvider},
    Config, RustBertError,
};
use rust_tokenizers::tokenizer::{DeBERTaTokenizer, MultiThreadedTokenizer, TruncationStrategy};
use std::env;
use tch::{nn, no_grad, Device, Kind, Tensor};

fn predict(input: &String) -> Result<Tensor, RustBertError> {
    // resources paths
    let config_resource = Box::new(RemoteResource::from_pretrained(
        DebertaConfigResources::DEBERTA_BASE_MNLI,
    ));
    let vocab_resource = Box::new(RemoteResource::from_pretrained(
        DebertaVocabResources::DEBERTA_BASE_MNLI,
    ));
    let merges_resource = Box::new(RemoteResource::from_pretrained(
        DebertaMergesResources::DEBERTA_BASE_MNLI,
    ));
    let model_resource = Box::new(RemoteResource::from_pretrained(
        DebertaModelResources::DEBERTA_BASE_MNLI,
    ));

    let config_path = config_resource.get_local_path()?;
    let vocab_path = vocab_resource.get_local_path()?;
    let merges_path = merges_resource.get_local_path()?;

    // set up the model
    let device = Device::Cpu;
    let mut vs = nn::VarStore::new(device);
    let tokenizer = DeBERTaTokenizer::from_file(
        vocab_path.to_str().unwrap(),
        merges_path.to_str().unwrap(),
        false,
    )?;
    let config = DebertaConfig::from_file(config_path);
    let model = DebertaForSequenceClassification::new(vs.root(), &config)?;
    load_weights(&model_resource, &mut vs)?;

    let tokenized_input = MultiThreadedTokenizer::encode_list(
        &tokenizer,
        &[input],
        128,
        &TruncationStrategy::LongestFirst,
        0,
    );
    let max_len = tokenized_input
        .iter()
        .map(|input| input.token_ids.len())
        .max()
        .unwrap();
    let tokenized_input = tokenized_input
        .iter()
        .map(|input| input.token_ids.clone())
        .map(|mut input| {
            input.extend(vec![0; max_len - input.len()]);
            input
        })
        .map(|input| Tensor::from_slice(&(input)))
        .collect::<Vec<_>>();
    let input_tensor = Tensor::stack(tokenized_input.as_slice(), 0).to(device);

    // forward pass
    let model_output =
        no_grad(|| model.forward_t(Some(&input_tensor), None, None, None, None, false))?;

    return Ok(model_output.logits.softmax(-1, Kind::Float));
}

fn main() {
    // define input
    let argv: Vec<String> = env::args().collect();
    let argc: usize = argv.len();
    if argc == 1 || argc > 2 {
        println!("{}", format!("Usage: {} \"Input sentence\"", argv[0]));
        return; // FIXME: throw error
    }
    let input_sentence = &argv[1];

    match predict(input_sentence) {
        Ok(probabilities) => probabilities.print(),
        Err(err) => panic!("{}", err),
    }
}
