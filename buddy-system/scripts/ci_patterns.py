# Optional gate helper for Go repositories whose CI workflow selects integration and e2e tests
# by `go test -run` pattern. Prints "<tags>\t<pkgs>\t<pattern>" for every go test -run in the
# workflow, and for every tagged go test with no -run (pattern "." = the whole package), so a
# gate can run each pattern on its own scratch database and report pass and skip counts.
# Usage: python3 ci_patterns.py <path/to/workflow.yml>
import re,sys
lines=open(sys.argv[1]).read().split('\n')
for i,l in enumerate(lines):
    m=re.search(r"-run '([^']+)'",l)
    if not m:
        if 'go test' in l and re.search(r'-tags (integration|e2e)',l) and '-run' not in l and not l.strip().endswith('\\'):
            tags='e2e' if '-tags e2e' in l else 'integration'
            pk=re.findall(r'(?<![\w/])\./[\w./-]*',l[l.find('go test'):])
            if pk: print(f"{tags}\t{' '.join(pk)}\t.")
        continue
    ctx=' '.join(lines[max(0,i-4):i+1])
    gt=ctx[ctx.rfind('go test'):] if 'go test' in ctx else ctx
    tags='e2e' if '-tags e2e' in gt else ('integration' if '-tags integration' in gt else '')
    pk=re.findall(r'(?<![\w/])\./[\w./-]*',gt.split("-run")[0]) or re.findall(r'(?<![\w/])\./[\w./-]*',gt)
    print(f"{tags}\t{' '.join(pk) if pk else '?'}\t{m.group(1)}")
