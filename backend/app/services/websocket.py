from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
import json
import time

from app.core import security as auth
from app.crud import crud
from app.db.database import get_db

router = APIRouter(tags=["websockets"])

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_personal_message(self, message: str, receiver_id: int):
        if receiver_id in self.active_connections:
            await self.active_connections[receiver_id].send_text(message)

manager = ConnectionManager()

@router.websocket("/ws/chat")
async def websocket_endpoint(websocket: WebSocket, token: str, db: Session = Depends(get_db)):
    user = auth.get_current_user_from_token(token, db)
    if not user:
        await websocket.close(code=1008)
        return
        
    await manager.connect(websocket, user.id)
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            
            receiver_id = payload.get("receiver_id")
            content = payload.get("content")
            message_type = payload.get("message_type", "text")
            
            if receiver_id and content:
                timestamp = time.time()
                crud.save_message(db, sender_id=user.id, receiver_id=receiver_id, content=content, message_type=message_type, timestamp=timestamp)
                
                out_payload = {
                    "sender_id": user.id,
                    "receiver_id": receiver_id,
                    "content": content,
                    "message_type": message_type,
                    "timestamp": timestamp
                }
                await manager.send_personal_message(json.dumps(out_payload), receiver_id)
                await manager.send_personal_message(json.dumps(out_payload), user.id)
                
    except WebSocketDisconnect:
        manager.disconnect(user.id)
    except Exception as e:
        print(f"WebSocket Error: {e}")
        manager.disconnect(user.id)
