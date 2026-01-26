# ADR-0003: Use Bash for Processing Scripts

## Status

Accepted

## Context

We need to process large XML files (Planet dumps), download data from APIs, and orchestrate complex ETL workflows. The scripts need to be maintainable, debuggable, and runnable on Linux systems.

## Decision

We will use Bash (Bourne Again Shell) as the primary scripting language for processing scripts and orchestration.

## Consequences

### Positive

- **Ubiquitous**: Available on all Linux systems by default
- **System integration**: Excellent integration with system tools (grep, awk, sed, curl, etc.)
- **Process orchestration**: Easy to run external commands and manage processes
- **Text processing**: Strong text processing capabilities with standard tools
- **No dependencies**: No need to install interpreters or runtime environments
- **Performance**: Direct system calls, no VM overhead
- **Debugging**: Easy to debug with shell debugging tools

### Negative

- **Error handling**: Bash error handling can be verbose
- **Complexity**: Complex scripts can be hard to maintain
- **Testing**: Less mature testing frameworks compared to other languages
- **Type safety**: No type checking or compile-time validation

## Alternatives Considered

### Alternative 1: Python

- **Description**: Use Python for all processing scripts
- **Pros**: Rich ecosystem, good libraries, easier to test, better error handling
- **Cons**: Requires Python installation, slower for simple system operations, more dependencies
- **Why not chosen**: Bash is more suitable for system-level orchestration and doesn't require additional dependencies

### Alternative 2: Node.js

- **Description**: Use Node.js/JavaScript for processing
- **Pros**: Modern language, good async support, large ecosystem
- **Cons**: Requires Node.js installation, not ideal for system-level operations, more overhead
- **Why not chosen**: Overkill for system orchestration tasks, adds unnecessary dependencies

### Alternative 3: Perl

- **Description**: Use Perl for text processing
- **Pros**: Excellent text processing, mature ecosystem
- **Cons**: Less readable, declining popularity, requires Perl installation
- **Why not chosen**: Bash + standard tools (awk, sed) provide sufficient text processing capabilities

## References

- [Bash Guide](https://www.gnu.org/software/bash/manual/)
- [Shell Script Best Practices](https://google.github.io/styleguide/shellguide.html)
