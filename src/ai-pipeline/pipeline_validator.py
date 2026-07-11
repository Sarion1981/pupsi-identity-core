# Studio PUPSI - Automated AI Pipeline Cryptographic Guardrail
# Mitigates supply-chain tampering by enforcing deterministic artifact validation.

import hashlib
import os
import sys

class PipelineValidator:
    def __init__(self, expected_release_hash: str):
        self.expected_hash = expected_release_hash

    def verify_artifact_integrity(self, file_path: str) -> bool:
        """
        Computes the SHA-256 checksum of an incoming AI model or configuration artifact
        and compares it against the immutable compliance record.
        """
        if not os.path.exists(file_path):
            print(f"[ERROR] Artifact not found at specified path: {file_path}", file=sys.stderr)
            return False

        sha256_hash = hashlib.sha256()
        
        # Read file in safe binary chunks to prevent memory overflows
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        
        computed_hash = sha256_hash.hexdigest()
        
        if computed_hash != self.expected_hash:
            print(f"[CRITICAL SECURITY BREACH] Artifact tampering detected! "
                  f"Computed: {computed_hash} | Expected: {self.expected_hash}", file=sys.stderr)
            return False
            
        print(f"[COMPLIANCE SUCCESS] Artifact integrity verified: {computed_hash}")
        return True

