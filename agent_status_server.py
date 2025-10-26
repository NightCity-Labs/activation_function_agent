"""
Agent status tracking server using Redis (reuses ncl_agents cursor service infrastructure).
Tracks what agents are running, what they're doing, and their status.
"""

import asyncio
import json
from datetime import datetime
from typing import Optional, Dict, Any, List
import redis.asyncio as redis
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import uvicorn


class AgentStatusTracker:
    """Track agent status using Redis (compatible with ncl_agents cursor service)."""
    
    def __init__(self, redis_url: str = "redis://localhost:6379/0"):
        self.redis_url = redis_url
        self.client: Optional[redis.Redis] = None
        self.prefix = "activation_agent:"
    
    async def connect(self):
        """Connect to Redis."""
        if self.client is None:
            self.client = await redis.from_url(self.redis_url)
            await self.client.ping()
    
    async def disconnect(self):
        """Disconnect from Redis."""
        if self.client:
            await self.client.close()
            self.client = None
    
    async def register_agent(self, agent_id: str, agent_type: str, 
                            workflow: str, project: str, 
                            metadata: Optional[Dict] = None) -> None:
        """Register a new agent run."""
        if not self.client:
            await self.connect()
        
        agent_data = {
            "agent_id": agent_id,
            "agent_type": agent_type,
            "workflow": workflow,
            "project": project,
            "status": "starting",
            "started_at": datetime.utcnow().isoformat(),
            "last_heartbeat": datetime.utcnow().isoformat(),
            "metadata": json.dumps(metadata or {})
        }
        
        key = f"{self.prefix}agent:{agent_id}"
        await self.client.hset(key, mapping=agent_data)
        
        # Add to active agents set
        await self.client.sadd(f"{self.prefix}active", agent_id)
    
    async def update_status(self, agent_id: str, status: str, 
                           current_task: Optional[str] = None,
                           progress: Optional[Dict] = None) -> None:
        """Update agent status."""
        if not self.client:
            await self.connect()
        
        key = f"{self.prefix}agent:{agent_id}"
        updates = {
            "status": status,
            "last_heartbeat": datetime.utcnow().isoformat()
        }
        
        if current_task:
            updates["current_task"] = current_task
        if progress:
            updates["progress"] = json.dumps(progress)
        
        await self.client.hset(key, mapping=updates)
    
    async def complete_agent(self, agent_id: str, status: str = "completed",
                            result_summary: Optional[str] = None,
                            error: Optional[str] = None) -> None:
        """Mark agent as completed."""
        if not self.client:
            await self.connect()
        
        key = f"{self.prefix}agent:{agent_id}"
        updates = {
            "status": status,
            "completed_at": datetime.utcnow().isoformat(),
            "last_heartbeat": datetime.utcnow().isoformat()
        }
        
        if result_summary:
            updates["result_summary"] = result_summary
        if error:
            updates["error"] = error
        
        await self.client.hset(key, mapping=updates)
        
        # Remove from active set
        await self.client.srem(f"{self.prefix}active", agent_id)
    
    async def get_agent_status(self, agent_id: str) -> Optional[Dict]:
        """Get status for a specific agent."""
        if not self.client:
            await self.connect()
        
        key = f"{self.prefix}agent:{agent_id}"
        data = await self.client.hgetall(key)
        
        if not data:
            return None
        
        result = {k.decode('utf-8'): v.decode('utf-8') for k, v in data.items()}
        
        # Parse JSON fields
        if 'metadata' in result:
            try:
                result['metadata'] = json.loads(result['metadata'])
            except:
                pass
        if 'progress' in result:
            try:
                result['progress'] = json.loads(result['progress'])
            except:
                pass
        
        return result
    
    async def get_active_agents(self) -> List[Dict]:
        """Get all active agents."""
        if not self.client:
            await self.connect()
        
        active_ids = await self.client.smembers(f"{self.prefix}active")
        agents = []
        
        for agent_id_bytes in active_ids:
            agent_id = agent_id_bytes.decode('utf-8')
            status = await self.get_agent_status(agent_id)
            if status:
                agents.append(status)
        
        return agents
    
    async def get_all_agents(self, limit: int = 100) -> List[Dict]:
        """Get all agents (active and completed)."""
        if not self.client:
            await self.connect()
        
        agents = []
        cursor = 0
        
        while True:
            cursor, keys = await self.client.scan(
                cursor=cursor,
                match=f"{self.prefix}agent:*",
                count=100
            )
            
            for key in keys:
                agent_id = key.decode('utf-8').replace(f"{self.prefix}agent:", '')
                status = await self.get_agent_status(agent_id)
                if status:
                    agents.append(status)
            
            if cursor == 0 or len(agents) >= limit:
                break
        
        # Sort by started_at desc
        agents.sort(key=lambda x: x.get('started_at', ''), reverse=True)
        return agents[:limit]


# FastAPI app
app = FastAPI(title="Activation Function Agent Status", version="0.1.0")
tracker = AgentStatusTracker()


@app.on_event("startup")
async def startup():
    await tracker.connect()


@app.on_event("shutdown")
async def shutdown():
    await tracker.disconnect()


@app.get("/")
async def root():
    return JSONResponse({
        "service": "activation_function_agent_status",
        "version": "0.1.0",
        "endpoints": [
            {"path": "/agents/active", "method": "GET"},
            {"path": "/agents/all", "method": "GET"},
            {"path": "/agents/{agent_id}", "method": "GET"},
            {"path": "/agents/register", "method": "POST"},
            {"path": "/agents/{agent_id}/status", "method": "PUT"},
            {"path": "/agents/{agent_id}/complete", "method": "POST"}
        ]
    })


@app.get("/agents/active")
async def get_active_agents():
    """Get all currently active agents."""
    try:
        agents = await tracker.get_active_agents()
        return JSONResponse({"status": "ok", "count": len(agents), "agents": agents})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/agents/all")
async def get_all_agents(limit: int = 100):
    """Get all agents (active and completed)."""
    try:
        agents = await tracker.get_all_agents(limit=limit)
        return JSONResponse({"status": "ok", "count": len(agents), "agents": agents})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/agents/{agent_id}")
async def get_agent(agent_id: str):
    """Get status for a specific agent."""
    try:
        status = await tracker.get_agent_status(agent_id)
        if not status:
            raise HTTPException(status_code=404, detail="Agent not found")
        return JSONResponse({"status": "ok", "agent": status})
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/agents/register")
async def register_agent(payload: Dict[str, Any]):
    """Register a new agent."""
    try:
        agent_id = payload.get("agent_id")
        if not agent_id:
            raise HTTPException(status_code=400, detail="agent_id required")
        
        await tracker.register_agent(
            agent_id=agent_id,
            agent_type=payload.get("agent_type", "cursor-agent"),
            workflow=payload.get("workflow", "unknown"),
            project=payload.get("project", "unknown"),
            metadata=payload.get("metadata")
        )
        
        return JSONResponse({"status": "ok", "agent_id": agent_id})
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/agents/{agent_id}/status")
async def update_agent_status(agent_id: str, payload: Dict[str, Any]):
    """Update agent status."""
    try:
        await tracker.update_status(
            agent_id=agent_id,
            status=payload.get("status", "running"),
            current_task=payload.get("current_task"),
            progress=payload.get("progress")
        )
        return JSONResponse({"status": "ok", "agent_id": agent_id})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/agents/{agent_id}/complete")
async def complete_agent(agent_id: str, payload: Dict[str, Any]):
    """Mark agent as completed."""
    try:
        await tracker.complete_agent(
            agent_id=agent_id,
            status=payload.get("status", "completed"),
            result_summary=payload.get("result_summary"),
            error=payload.get("error")
        )
        return JSONResponse({"status": "ok", "agent_id": agent_id})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8082, log_level="info")

