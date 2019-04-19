#!/usr/bin/env python3

import sys
import glob

import yaml

pattern_file = sys.argv[1]
patterns = yaml.safe_load(open(pattern_file))

for pattern in patterns:
    for match in glob.glob(pattern['match']):
        ignore = False
        for ignore_pattern in pattern.get('ignore', []):
            # print("="*29)
            # print(match)
            # print(ignore_pattern)
            if match.startswith(ignore_pattern):
                print("IGNORE " + match)
                ignore = True
                continue
        if not ignore:
            print("MATCH")
            print(match)

