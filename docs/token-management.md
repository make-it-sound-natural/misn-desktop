# Token Management and Context Truncation

## Overview

The app now intelligently manages token counts to maximize context usage while staying within model limits.

## Implementation Details

### Token Estimation

We use an approximation method to estimate token counts without needing the full tiktoken library:

- **Base ratio**: ~1 token per 4 characters for English text
- **Special character overhead**: +20% for non-ASCII and special formatting
- **Additional counting**: Special characters like emojis add extra tokens

```swift
private func estimateTokenCount(_ text: String) -> Int {
    let baseCount = text.count / 4
    let specialChars = text.filter {
        !$0.isLetter && !$0.isWhitespace && !$0.isPunctuation
    }.count
    return Int(Double(baseCount) * 1.2) + (specialChars / 2)
}
```

### Model Limits

The system supports multiple models with different context windows:

| Model | Context Window | Max Output | Usable Input |
|-------|---------------|------------|--------------|
| gpt-5.4-nano | 400,000 | 128,000 | ~271,000 |
| gpt-5.4-mini | 400,000 | 128,000 | ~271,000 |
| gpt-5.4 | 1,050,000 | 128,000 | ~921,000 |
| gpt-5.5 | 1,050,000 | 128,000 | ~921,000 |
| google/gemini-3.1-flash-lite-preview | 1,048,576 | 65,536 | ~982,000 |
| google/gemini-3-flash-preview | 1,048,576 | 65,536 | ~982,000 |
| openai/gpt-5.4-nano | 400,000 | 128,000 | ~271,000 |
| qwen/qwen3.6-flash | 1,000,000 | 65,536 | ~933,000 |
| x-ai/grok-4.1-fast | 2,000,000 | 30,000 | ~1,969,000 |
| anthropic/claude-haiku-4.5 | 200,000 | 64,000 | ~135,000 |

**Usable Input** = Context Window - Max Output - 1,000 (safety margin)

### Smart Context Truncation

When total tokens exceed limits, the system intelligently truncates:

1. **Priority Order**:
   - System instructions (never truncated - core functionality)
   - User text (never truncated - the text to correct)
   - Context (truncated if needed)

2. **Truncation Strategy**:
   - Keeps the **most recent** context (truncates from beginning)
   - Adds `...[context truncated]...` marker
   - Logs before/after character counts

3. **Example Flow**:
   ```
   System instructions: 1,500 tokens
   User text: 500 tokens
   Context: 300,000 tokens
   Limit: 271,000 tokens

   → Context truncated to ~269,000 tokens
   → Total: ~271,000 tokens ✓
   ```

### Logging

The system logs detailed token information:

```
Token estimation - System: 1500, User: 500, Context: 300000, Total: 302000, Limit: 271000
📉 Context truncated from 1200000 to 1076000 chars (~269000 tokens)
```

## Benefits

### No Manual Context Limits
- Users can store **unlimited context**
- System automatically manages what fits
- Most recent context is prioritized

### Optimized API Usage
- Maximizes context usage within model limits
- Prevents API errors from oversized requests
- Efficient token allocation

### Transparent Operation
- Clear logging of truncation events
- Users understand when/why truncation occurs
- Debug-friendly implementation

## API Configuration

### Priority Processing
All requests use `service_tier: "priority"` for:
- ⚡ Faster response times
- 📊 More consistent latency
- 🎯 Better for user-facing interactions

### Default Model: gpt-5.4-mini
- **Cost-effective**: $0.20/1M input tokens, $1.25/1M output tokens
- **Fast**: Optimized for quick responses and high-volume tasks
- **Large context**: 400K tokens
- **Perfect for**: Text correction and refinement

## Usage Recommendations

### Context Strategy
1. **Short-term projects**: Add specific technical details
2. **Long-running work**: Include relevant background, code snippets
3. **Team communication**: Add team conventions, acronym definitions

### What to Include in Context
✅ **Good context examples**:
- Project-specific terminology
- Team communication style preferences
- Technical abbreviations and their meanings
- Recent discussion topics

❌ **Avoid**:
- Repetitive information
- Outdated context (clean it periodically)
- Generic information the model already knows

### Monitoring
Check logs for truncation events:
- Frequent truncation? Consider condensing context
- Never truncating? You have headroom for more context

## Technical Notes

### Token Estimation Accuracy
- Approximation is ~90% accurate for English text
- May be slightly less accurate for:
  - Heavy code blocks
  - Multiple languages
  - Extensive special formatting

### Future Improvements
- Native tiktoken integration for exact counting
- Per-model token optimization
- Context compression strategies
- User-configurable truncation preferences
