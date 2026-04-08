from fastapi import FastAPI

app = FastAPI(title="Pulse API", version="0.1.0")

@app.get("/")
def root():
    return {"message": "Pulse API is running"}

@app.get("/health")
def health():
    return {"status": "ok"}