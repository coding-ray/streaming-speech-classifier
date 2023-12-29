use rust_bert::{
    pipelines::{
        common::{ModelResource, ModelType},
        sequence_classification::Label,
        zero_shot_classification::{ZeroShotClassificationConfig, ZeroShotClassificationModel},
    },
    resources::LocalResource,
    RustBertError,
};
use std::{env, path::PathBuf};
use tch::Device;

const PATH_MODEL: &str = "src/model/rust_model.ot";
const PATH_MODEL_MERGE_SCRIPT: &str = "bin/merge-model-parts.sh";
const CATEGORIES: [&str; 2] = ["science", "politics"];

enum ResourceType {
    Config,
    Model,
    Merges,
    Vocab,
}

fn get_local_resource(resource_type: ResourceType, path_str: &str) -> Box<LocalResource> {
    fn box_it(path_str: &str) -> Box<LocalResource> {
        Box::new(LocalResource::from(PathBuf::from(path_str)))
    }

    fn get_or_generate_model_local_resource(path_str: &str) -> Box<LocalResource> {
        let path = std::path::Path::new(path_str);
        if path.exists() {
            return box_it(path_str);
        }

        // merge model from model parts
        std::process::Command::new(PATH_MODEL_MERGE_SCRIPT)
            .spawn()
            .expect(format!("Cannot execute {}.", PATH_MODEL_MERGE_SCRIPT).as_str())
            .wait()
            .expect("Cannot create the model from the model parts.");

        if path.exists() {
            return box_it(path_str);
        } else {
            panic!("Cannot find the model {}.", path_str);
        }
    }

    match resource_type {
        ResourceType::Model => return get_or_generate_model_local_resource(path_str),
        ResourceType::Config | ResourceType::Merges | ResourceType::Vocab => {
            return box_it(path_str)
        }
    }
}

fn predict(input: &String) -> Result<Vec<Label>, RustBertError> {
    // resources
    let model_resource = get_local_resource(ResourceType::Model, PATH_MODEL);
    let config_resource = get_local_resource(ResourceType::Config, "src/config/main.json");
    let vocab_resource = get_local_resource(ResourceType::Vocab, "src/config/vocab.json");
    let merges_resource = get_local_resource(ResourceType::Merges, "src/config/merges.txt");
    let device = Device::Cpu; // match LibTorch version

    // set up the model
    let complete_config = ZeroShotClassificationConfig {
        model_type: ModelType::Deberta,
        model_resource: ModelResource::Torch(model_resource),
        config_resource,
        vocab_resource: vocab_resource.clone(),
        merges_resource: Some(merges_resource.clone()),
        device,
        ..Default::default()
    };
    let model = ZeroShotClassificationModel::new(complete_config)?;

    // predict and return scores for the provided labels
    let output: Vec<Vec<Label>> = model.predict_multilabel([input.as_str()], CATEGORIES, None, 128)?;

    return Ok(output[0].clone());
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
        Ok(output_logits) => {
            println!("{:^10} {:^7}", "Category", "Score");
            for logit in output_logits {
                println!("{:^10} {:<7.4}", logit.text, logit.score);
            }
        }
        Err(err) => panic!("{}", err),
    }
}
