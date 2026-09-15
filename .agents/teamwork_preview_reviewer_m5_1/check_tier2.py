import re

with open('test/e2e/e2e_tier2_r1_r2_test.dart', 'r', encoding='utf-8') as fp:
    lines = fp.readlines()

current_group = None
group_tests = {}
for idx, line in enumerate(lines, 1):
    g_match = re.search(r"group\s*\(\s*['\"]([^'\"]+)['\"]", line)
    if g_match:
        current_group = g_match.group(1)
        group_tests[current_group] = []
    t_match = re.search(r"(testWidgets|test)\s*\(\s*['\"]([^'\"]+)['\"]", line)
    if t_match and current_group:
        group_tests[current_group].append((t_match.group(1), t_match.group(2), idx))

for g, tests in group_tests.items():
    print(f"Group: {g} -> {len(tests)} tests")
    for t_type, name, line_no in tests:
        pass
    if len(tests) < 5:
        print(f"  *** LESS THAN 5 TESTS ({len(tests)}) ***")
        for t_type, name, line_no in tests:
            print(f"    Line {line_no}: [{t_type}] {name}")
