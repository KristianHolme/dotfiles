# Investigation brief

The subagent returns, for each key result in scope, a brief of this shape:

```markdown
### Key operations
 - **Code locations**: file:line ranges that correspond to models or analyses
 - **Purpose**: what this block exists to do
 - **Operation**: the mathematical equivalent of the same operation (TeX-style math)

### Result: [what it is — a number, a figure, a claim]
- **Origin chain**: data subset used → transform/model → parametrization → output
- **Code locations**: file:line for the load-bearing steps
- **Ground-truth handling**: how ground truth was generated/used, if applicable
- **Verified**: which steps were checked against the code (vs. taken from the plan/Notes)
- **Discrepancies**: where the code disagrees with the plan/Notes, or "none found"
- **Risk flags**: assumptions most likely to be misaligned with user intent;
  results that look "too good" or "too bad" to be true
```
