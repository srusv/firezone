use clap::Args;
use tracing_subscriber::{
    fmt, prelude::__tracing_subscriber_SubscriberExt, EnvFilter, Layer, Registry,
};
use url::Url;

pub fn block_on_ctrl_c() {
    let (tx, rx) = std::sync::mpsc::channel();
    ctrlc::set_handler(move || tx.send(()).expect("Could not send stop signal on channel."))
        .expect("Error setting Ctrl-C handler");
    rx.recv().expect("Could not receive ctrl-c signal");
}

pub fn setup_global_subscriber<L>(additional_layer: L)
where
    L: Layer<Registry> + Send + Sync,
{
    let subscriber = Registry::default()
        .with(additional_layer.with_filter(EnvFilter::from_default_env()))
        .with(fmt::layer().with_filter(EnvFilter::from_default_env()));
    tracing::subscriber::set_global_default(subscriber).expect("Could not set global default");
}

/// Arguments common to all Firezone CLI components.
#[derive(Args, Clone)]
pub struct CommonArgs {
    /// Firezone admin portal websocket URL
    #[arg(
        short = 'u',
        long,
        env = "PORTAL_URL",
        default_value = "wss://api.firezone.dev"
    )]
    pub portal_url: Url,
    /// Token generated by the portal to authorize websocket connection.
    #[arg(short = 't', long, env = "PORTAL_TOKEN")]
    pub portal_token: String,
}
