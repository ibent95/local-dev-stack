use axum::{routing::get, Json, Router};
use serde_json::{json, Value};

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(|| async { "ok" }));

    // Backing services on the lds-network network: mysql:3306, postgres:5432,
    // redis:6379, kafka-broker:9092 ...
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .unwrap();
    println!("rust listening on :3000");
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> Json<Value> {
    let host = std::env::var("HOSTNAME").unwrap_or_default();
    Json(json!({
        "service": "rust",
        "message": "Hello from Rust + axum",
        "hostname": host,
    }))
}
