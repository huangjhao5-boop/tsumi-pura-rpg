import re

files = [
    'test/e2e/e2e_tier1_r1_r2_test.dart',
    'test/e2e/e2e_tier1_r3_r4_test.dart',
    'test/e2e/e2e_tier2_r1_r2_test.dart',
    'test/e2e/e2e_tier2_r3_r4_test.dart',
    'test/e2e/e2e_tier3_pairwise_test.dart',
    'test/e2e/e2e_tier4_scenarios_test.dart'
]

dummy_patterns = [
    r'expect\s*\(\s*true\s*,\s*(isTrue|true)\s*\)',
    r'expect\s*\(\s*false\s*,\s*(isFalse|false)\s*\)',
    r'expect\s*\(\s*1\s*,\s*1\s*\)',
    r'expect\s*\(\s*0\s*,\s*0\s*\)',
    r'expect\s*\(\s*["\']a["\']\s*,\s*["\']a["\']\s*\)',
]

print("=== ASSERTION AUDIT ===")
for f in files:
    with open(f, 'r', encoding='utf-8') as fp:
        content = fp.read()
    
    expect_calls = re.findall(r'\bexpect\s*\(', content)
    finds_one = len(re.findall(r'findsOneWidget', content))
    finds_nothing = len(re.findall(r'findsNothing', content))
    finds_n = len(re.findall(r'findsNWidgets', content))
    
    print(f"\n{f}:")
    print(f"  Total `expect` calls: {len(expect_calls)}")
    print(f"  UI finders: findsOneWidget={finds_one}, findsNothing={finds_nothing}, findsNWidgets={finds_n}")
    
    # Check for dummy patterns
    dummy_count = 0
    for p in dummy_patterns:
        matches = re.findall(p, content)
        if matches:
            print(f"  WARNING: Dummy assertion found matching {p}: {len(matches)}")
            dummy_count += len(matches)
    if dummy_count == 0:
        print("  Zero dummy assertions detected.")
