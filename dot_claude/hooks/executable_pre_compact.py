#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "python-dotenv",
# ]
# ///

import argparse
import json
import os
import sys
from pathlib import Path
from datetime import datetime

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv is optional


def chats_dir_for(cwd: str) -> Path:
    """Return ~/code/chats/<sanitized-cwd>/, creating it if needed."""
    sanitized = cwd.lstrip('/').replace('/', '_') or 'root'
    target = Path.home() / 'code' / 'chats' / sanitized
    target.mkdir(parents=True, exist_ok=True)
    return target


def backup_transcript(transcript_path, trigger, session_id):
    """Snapshot the transcript before compaction into ~/code/chats/<project>/."""
    try:
        if not os.path.exists(transcript_path):
            return None

        target_dir = chats_dir_for(os.getcwd())
        ts = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        backup_path = target_dir / f"claude_{ts}_{session_id}_pre-compact-{trigger}.jsonl"

        import shutil
        shutil.copy2(transcript_path, backup_path)

        return str(backup_path)
    except Exception:
        return None


def main():
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser()
        parser.add_argument('--backup', action='store_true',
                          help='Create backup of transcript before compaction')
        parser.add_argument('--verbose', action='store_true',
                          help='Print verbose output')
        args = parser.parse_args()
        
        # Read JSON input from stdin
        input_data = json.loads(sys.stdin.read())
        
        # Extract fields
        session_id = input_data.get('session_id', 'unknown')
        transcript_path = input_data.get('transcript_path', '')
        trigger = input_data.get('trigger', 'unknown')  # "manual" or "auto"
        custom_instructions = input_data.get('custom_instructions', '')

        # Create backup if requested
        backup_path = None
        if args.backup and transcript_path:
            backup_path = backup_transcript(transcript_path, trigger, session_id)
        
        # Provide feedback based on trigger type
        if args.verbose:
            if trigger == "manual":
                message = f"Preparing for manual compaction (session: {session_id[:8]}...)"
                if custom_instructions:
                    message += f"\nCustom instructions: {custom_instructions[:100]}..."
            else:  # auto
                message = f"Auto-compaction triggered due to full context window (session: {session_id[:8]}...)"
            
            if backup_path:
                message += f"\nTranscript backed up to: {backup_path}"
            
            print(message)
        
        # Success - compaction will proceed
        sys.exit(0)
        
    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)


if __name__ == '__main__':
    main()