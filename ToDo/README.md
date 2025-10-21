# ToDo Directory

Version: 2025-10-21

This directory contains all TODO items, action plans, and progress tracking for the OSM-Notes-Ingestion project.

---

## Files Overview

### 📋 ActionPlan.md
**Purpose**: Comprehensive action plan with all identified tasks  
**Use for**: 
- Detailed task breakdown
- Task status tracking
- Priority classification
- Complete project roadmap

**How to use**:
1. Find tasks by priority or category
2. Mark [🔄] when starting work
3. Mark [✅] when completed
4. Add notes on implementation details

**Status Markers**:
- `[ ]` Not started
- `[🔄]` In progress
- `[✅]` Completed
- `[❌]` Cancelled/Not needed

---

### 🎯 ProgressTracker.md
**Purpose**: Quick daily/weekly progress view  
**Use for**:
- Sprint planning
- Daily standups
- Weekly reviews
- Quick statistics

**How to use**:
1. Update weekly goals at start of sprint
2. Log daily progress in weekly section
3. Update quick stats table
4. Track blockers and decisions

**Update frequency**: Daily or as tasks complete

---

### 📝 ToDos.md
**Purpose**: Original feature requests and improvements  
**Use for**:
- Feature ideas
- Enhancement requests
- Long-term planning

**Status**: Reference document, tasks migrated to ActionPlan.md

---

### 🐛 errors.md
**Purpose**: Known bugs and errors encountered  
**Use for**:
- Bug documentation
- Error reproduction steps
- Solution tracking

**Status**: Active reference, critical items in ActionPlan.md

---

### 💡 prompts
**Purpose**: Improvement suggestions and refactoring guidelines  
**Use for**:
- Code quality guidelines
- Refactoring tasks
- Best practices

**Status**: Reference document, tasks migrated to ActionPlan.md

---

## Workflow

### Starting a New Sprint

1. Review `ActionPlan.md` for next priority items
2. Update `ProgressTracker.md` with sprint goals
3. Create GitHub issues for major tasks (optional)
4. Mark items as [🔄] in progress

### During Development

1. Work on tasks from current sprint
2. Update `ProgressTracker.md` daily log
3. Mark completed items [✅] in `ActionPlan.md`
4. Document blockers in `ProgressTracker.md`

### Sprint Review

1. Update statistics in both files
2. Log completed items in `ProgressTracker.md`
3. Plan next sprint in `ProgressTracker.md`
4. Review and adjust priorities if needed

### Adding New Tasks

1. Add to appropriate section in `ActionPlan.md`
2. Assign priority level
3. Update statistics
4. Consider adding to current sprint if critical

---

## Priority Guidelines

### 🔴 Critical
- Bugs causing data loss or corruption
- Security vulnerabilities
- Blocking issues preventing normal operation
- **Timeline**: Fix immediately

### 🟡 High
- Important stability improvements
- Missing validations
- Error handling gaps
- **Timeline**: Fix within 1-2 weeks

### 🟠 Medium
- Functional improvements
- Performance optimizations
- Refactoring for maintainability
- **Timeline**: Fix within 1-2 months

### 🟢 Low
- New features
- Nice-to-have enhancements
- Documentation improvements
- **Timeline**: As time permits

### 📊 Refactoring
- Code cleanup
- Standardization
- Technical debt
- **Timeline**: Ongoing, parallel to other work

---

## Task Categories

- **Database Errors**: Data integrity and DB issues
- **Error Handling**: Robustness and resilience
- **Security**: Vulnerabilities and credentials
- **Validations**: Input and data validation
- **Monitoring**: System monitoring and alerts
- **ETL**: Data warehouse processes
- **Scalability**: Performance and capacity
- **Datamarts**: Analytics and reporting
- **Visualizer**: UI and visualization
- **Documentation**: Docs and diagrams
- **Refactoring**: Code quality and cleanup
- **Testing**: Test coverage and quality

---

## Statistics Tracking

Update these metrics in `ProgressTracker.md` weekly:

- **Total Items**: Count of all tasks
- **By Priority**: Breakdown by 🔴🟡🟠🟢📊
- **By Status**: Not started / In progress / Done / Cancelled
- **Completion Rate**: Percentage complete
- **Velocity**: Items completed per week

---

## Integration with Development

### Git Workflow

When working on tasks from ActionPlan:

```bash
# Create branch for task
git checkout -b fix/issue-1-foreign-key-violation

# Make changes
# ...

# Commit with reference
git commit -m "Fix: foreign key violation in note_comments_text

Resolves ActionPlan Issue #1
Adds deduplication logic before insert to prevent
duplicate comments from causing FK violations.

Tested with note 3037001 scenario."

# Update ActionPlan.md
# Mark [✅] Issue #1
# Update ProgressTracker.md
```

### GitHub Issues (Optional)

For major tasks, create GitHub issues:

```markdown
Title: Fix foreign key violation in note_comments_text

**Reference**: ActionPlan.md - Issue #1  
**Priority**: 🔴 Critical

**Description**:
NeisBot writing duplicate comments causes FK constraint violation.

**Example**: Note 3037001

**Solution**:
Add deduplication logic before insert

**Files**:
- SQL insert procedures
```

---

## Maintenance

### Weekly
- Update `ProgressTracker.md` progress log
- Review and prioritize upcoming tasks
- Update statistics

### Monthly
- Review overall progress in `ActionPlan.md`
- Adjust priorities based on project needs
- Archive completed sections if very large

### As Needed
- Add new tasks as discovered
- Update estimates and timelines
- Document blockers and decisions

---

## Tips

1. **Be realistic**: Don't mark items as done unless fully complete
2. **Document blockers**: If stuck, note why in ProgressTracker
3. **Update regularly**: Keep both files in sync
4. **Use references**: Link commits, PRs, and issues
5. **Celebrate wins**: Log completed items in ProgressTracker
6. **Adjust priorities**: Move urgent items up as needed
7. **Break down large tasks**: Split into smaller, actionable items

---

## Contact

If you discover new bugs or have feature ideas:

1. Add to `errors.md` (for bugs) or `prompts` (for ideas)
2. Create entry in `ActionPlan.md` with priority
3. Update statistics
4. Consider creating GitHub issue for visibility

---

**Last Updated**: 2025-10-21  
**Maintained By**: Project contributors

