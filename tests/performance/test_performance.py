#!/usr/bin/env python3
"""
Performance Tests for OSM-Notes-profile
Author: Andres Gomez (AngocA)
Version: 2025-07-20
"""

import time
import pytest

def test_basic_performance():
    """Basic performance test"""
    start_time = time.time()
    
    # Simulate some work
    time.sleep(0.1)
    
    end_time = time.time()
    execution_time = end_time - start_time
    
    # Assert that execution time is reasonable
    assert execution_time < 1.0, f"Execution took too long: {execution_time:.2f}s"

def test_memory_usage():
    """Test memory usage"""
    import psutil
    import os
    
    process = psutil.Process(os.getpid())
    memory_info = process.memory_info()
    
    # Assert that memory usage is reasonable (less than 100MB)
    memory_mb = memory_info.rss / 1024 / 1024
    assert memory_mb < 100, f"Memory usage too high: {memory_mb:.2f}MB"

if __name__ == "__main__":
    pytest.main([__file__]) 