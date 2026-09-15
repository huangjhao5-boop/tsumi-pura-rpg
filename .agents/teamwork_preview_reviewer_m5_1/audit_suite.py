import re

files = {
    'tier1_r1_r2': 'test/e2e/e2e_tier1_r1_r2_test.dart',
    'tier1_r3_r4': 'test/e2e/e2e_tier1_r3_r4_test.dart',
    'tier2_r1_r2': 'test/e2e/e2e_tier2_r1_r2_test.dart',
    'tier2_r3_r4': 'test/e2e/e2e_tier2_r3_r4_test.dart',
    'tier3': 'test/e2e/e2e_tier3_pairwise_test.dart',
    'tier4': 'test/e2e/e2e_tier4_scenarios_test.dart',
}

def analyze_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find groups
    groups = list(re.finditer(r"group\s*\(\s*['\"]([^'\"]+)['\"]", content))
    group_data = []
    for i, g in enumerate(groups):
        g_name = g.group(1)
        start_idx = g.start()
        end_idx = groups[i+1].start() if i+1 < len(groups) else len(content)
        g_content = content[start_idx:end_idx]

        # Find tests in this group
        tests = list(re.finditer(r"\b(testWidgets|test)\s*\(\s*['\"]([^'\"]+)['\"]", g_content))
        test_list = []
        for t in tests:
            t_type = t.group(1)
            t_name = t.group(2)
            # check content of the test
            test_start = t.start()
            # find next test or end of group
            # roughly find assertions
            test_list.append((t_type, t_name))

        group_data.append((g_name, test_list))
    return group_data

all_results = {}
total_all = 0
for key, path in files.items():
    res = analyze_file(path)
    count = sum(len(tests) for _, tests in res)
    total_all += count
    all_results[key] = (res, count)
    print(f"=== {key} ({path}) ===")
    print(f"  Groups: {len(res)}, Total Tests: {count}")
    for g_name, tests in res:
        print(f"    {g_name}: {len(tests)} tests")

print(f"\nTOTAL E2E TESTS IN SUITE: {total_all}")
