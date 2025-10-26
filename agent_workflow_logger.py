"""
Simple SQLite logger for cursor-agent and workflow calls.
Tracks agent invocations, workflow runs, and outcomes.
"""

import sqlite3
import json
from datetime import datetime
from typing import Optional, Dict, Any
from pathlib import Path


class AgentWorkflowLogger:
    def __init__(self, db_path: str = "/Users/cstein/code/activation_function_agent/agent_logs.db"):
        self.db_path = db_path
        self._init_db()
    
    def _init_db(self):
        """Initialize database schema if it doesn't exist."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Workflow runs table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS workflow_runs (
                run_id TEXT PRIMARY KEY,
                workflow_name TEXT NOT NULL,
                project_name TEXT NOT NULL,
                started_at TEXT NOT NULL,
                completed_at TEXT,
                status TEXT NOT NULL,
                model TEXT,
                flags TEXT,
                error_message TEXT,
                notes TEXT
            )
        """)
        
        # Agent calls table (for cursor-agent invocations)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS agent_calls (
                call_id TEXT PRIMARY KEY,
                run_id TEXT,
                agent_type TEXT NOT NULL,
                prompt TEXT NOT NULL,
                started_at TEXT NOT NULL,
                completed_at TEXT,
                status TEXT NOT NULL,
                model TEXT,
                output_summary TEXT,
                error_message TEXT,
                duration_ms INTEGER,
                FOREIGN KEY (run_id) REFERENCES workflow_runs(run_id)
            )
        """)
        
        # Artifacts table (files created/modified)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS artifacts (
                artifact_id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id TEXT NOT NULL,
                file_path TEXT NOT NULL,
                action TEXT NOT NULL,
                created_at TEXT NOT NULL,
                notes TEXT,
                FOREIGN KEY (run_id) REFERENCES workflow_runs(run_id)
            )
        """)
        
        conn.commit()
        conn.close()
    
    def start_workflow_run(self, run_id: str, workflow_name: str, project_name: str, 
                          model: Optional[str] = None, flags: Optional[Dict] = None) -> None:
        """Log the start of a workflow run."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO workflow_runs 
            (run_id, workflow_name, project_name, started_at, status, model, flags)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            run_id,
            workflow_name,
            project_name,
            datetime.utcnow().isoformat(),
            "running",
            model,
            json.dumps(flags) if flags else None
        ))
        
        conn.commit()
        conn.close()
    
    def complete_workflow_run(self, run_id: str, status: str, 
                             error_message: Optional[str] = None,
                             notes: Optional[str] = None) -> None:
        """Mark a workflow run as completed."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE workflow_runs 
            SET completed_at = ?, status = ?, error_message = ?, notes = ?
            WHERE run_id = ?
        """, (
            datetime.utcnow().isoformat(),
            status,
            error_message,
            notes,
            run_id
        ))
        
        conn.commit()
        conn.close()
    
    def log_agent_call(self, call_id: str, agent_type: str, prompt: str,
                      run_id: Optional[str] = None, model: Optional[str] = None) -> None:
        """Log the start of an agent call."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO agent_calls 
            (call_id, run_id, agent_type, prompt, started_at, status, model)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            call_id,
            run_id,
            agent_type,
            prompt,
            datetime.utcnow().isoformat(),
            "running",
            model
        ))
        
        conn.commit()
        conn.close()
    
    def complete_agent_call(self, call_id: str, status: str,
                           output_summary: Optional[str] = None,
                           error_message: Optional[str] = None,
                           duration_ms: Optional[int] = None) -> None:
        """Mark an agent call as completed."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE agent_calls 
            SET completed_at = ?, status = ?, output_summary = ?, error_message = ?, duration_ms = ?
            WHERE call_id = ?
        """, (
            datetime.utcnow().isoformat(),
            status,
            output_summary,
            error_message,
            duration_ms,
            call_id
        ))
        
        conn.commit()
        conn.close()
    
    def log_artifact(self, run_id: str, file_path: str, action: str, notes: Optional[str] = None) -> None:
        """Log a file artifact created/modified during a run."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO artifacts 
            (run_id, file_path, action, created_at, notes)
            VALUES (?, ?, ?, ?, ?)
        """, (
            run_id,
            file_path,
            action,
            datetime.utcnow().isoformat(),
            notes
        ))
        
        conn.commit()
        conn.close()
    
    def get_workflow_runs(self, project_name: Optional[str] = None, limit: int = 50):
        """Retrieve workflow runs, optionally filtered by project."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if project_name:
            cursor.execute("""
                SELECT * FROM workflow_runs 
                WHERE project_name = ?
                ORDER BY started_at DESC
                LIMIT ?
            """, (project_name, limit))
        else:
            cursor.execute("""
                SELECT * FROM workflow_runs 
                ORDER BY started_at DESC
                LIMIT ?
            """, (limit,))
        
        rows = cursor.fetchall()
        conn.close()
        
        return rows
    
    def get_run_details(self, run_id: str):
        """Get full details for a specific run including agent calls and artifacts."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get workflow run
        cursor.execute("SELECT * FROM workflow_runs WHERE run_id = ?", (run_id,))
        workflow = cursor.fetchone()
        
        # Get agent calls
        cursor.execute("SELECT * FROM agent_calls WHERE run_id = ?", (run_id,))
        agent_calls = cursor.fetchall()
        
        # Get artifacts
        cursor.execute("SELECT * FROM artifacts WHERE run_id = ?", (run_id,))
        artifacts = cursor.fetchall()
        
        conn.close()
        
        return {
            "workflow": workflow,
            "agent_calls": agent_calls,
            "artifacts": artifacts
        }


if __name__ == "__main__":
    # Test the logger
    logger = AgentWorkflowLogger()
    
    test_run_id = f"test_run_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"
    
    logger.start_workflow_run(
        run_id=test_run_id,
        workflow_name="kb_creation",
        project_name="test_project",
        model="sonnet-4.5-thinking",
        flags={"browser": True}
    )
    
    logger.log_agent_call(
        call_id=f"{test_run_id}_call_1",
        agent_type="cursor-agent",
        prompt="Test prompt",
        run_id=test_run_id,
        model="sonnet-4.5-thinking"
    )
    
    logger.complete_agent_call(
        call_id=f"{test_run_id}_call_1",
        status="success",
        output_summary="Created 3 files",
        duration_ms=45000
    )
    
    logger.log_artifact(
        run_id=test_run_id,
        file_path="/path/to/file.md",
        action="created"
    )
    
    logger.complete_workflow_run(
        run_id=test_run_id,
        status="success",
        notes="Test completed successfully"
    )
    
    print(f"Test run logged: {test_run_id}")
    print(f"Database: {logger.db_path}")

