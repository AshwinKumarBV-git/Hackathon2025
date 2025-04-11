import uvicorn
from app.api import app
from app.config import HOST, PORT, DEBUG

if __name__ == "__main__":
    uvicorn.run("app.api:app", host=HOST, port=PORT, reload=DEBUG)