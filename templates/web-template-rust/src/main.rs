use axum::{response::Html, routing::get, Router};

// Server-rendered web counterpart of svc-template-rust (which returns JSON).
#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(index))
        .route("/health", get(|| async { "ok" }));

    // Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .unwrap();
    println!("web-template-rust listening on :3000");
    axum::serve(listener, app).await.unwrap();
}

async fn index() -> Html<&'static str> {
    Html(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">\
         <title>web-template-rust</title>\
         <style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>\
         </head><body><h1>web-template-rust</h1>\
         <p>Hello from a Rust + axum server-rendered page.</p></body></html>",
    )
}
