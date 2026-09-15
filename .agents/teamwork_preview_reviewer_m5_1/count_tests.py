import os
import re

files = [
    'test/e2e/e2e_tier1_r1_r2_test.dart',
    'test/e2e/e2e_tier1_r3_r4_test.dart',
    'test/e2e/e2e_tier2_r1_r2_test.dart',
    'test/e2e/e2e_tier2_r3_r4_test.dart',
    'test/e2e/e2e_tier3_pairwise_test.dart',
    'test/e2e/e2e_tier4_scenarios_test.dart',
]

total_tests = 0
for f in files:
    with open(f, 'r', encoding='utf-8') as fp:
        content = fp.read()
    groups = re.findall(r"group\s*\(\s*['\"]([^'\"]+)['\"]", content)
    tests = re.findall(r"testWidgets\s*\(\s*['\"]([^'\"]+)['\"]", content)
    print(f"{f}:")
    print(f"  Groups ({len(groups)}):")
    for g in groups:
        # count how many tests are in this group
        # find substring from group to next group
        pos = content.find(g)
        pass
    print(f"  Total tests: {len(tests)}")
    total_tests += len(tests)

print(f"\nGRAND TOTAL E2E TESTS: {total_tests}")
