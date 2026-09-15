import re

with open('test/e2e/e2e_tier2_r1_r2_test.dart', 'r', encoding='utf-8') as fp:
    lines = fp.readlines()

current_group = None
test_types = {'testWidgets': 0, 'test': 0}
for idx, line in enumerate(lines, 1):
    g_match = re.search(r"group\s*\(\s*['\"]([^'\"]+)['\"]", line)
    if g_match:
        current_group = g_match.group(1)
    t_match = re.search(r"\b(testWidgets|test)\s*\(\s*['\"]([^'\"]+)['\"]", line)
    if t_match and current_group:
        ttype = t_match.group(1)
        test_types[ttype] += 1
        if ttype == 'test':
            print(f"Line {idx} in '{current_group}': uses 'test' -> {t_match.group(2)}")

print(f"\nSummary of test types: {test_types}")
