//! Concrete [`Observer`](soukoban::solver::Observer) implementations.

use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
};

use soukoban::solver::{Node, Observer};

/// Thread-safe search statistics for polling from another thread. Clone the
/// handle to share it between the solving thread and polling threads.
///
/// Both counters use relaxed atomics: `on_successor` fires on every generated
/// successor, so a lock per successor would be too expensive.
#[derive(Clone, Debug, Default)]
pub struct SearchStats {
    inner: Arc<SearchStatsInner>,
}

#[derive(Debug, Default)]
struct SearchStatsInner {
    expanded: AtomicU64,
    generated: AtomicU64,
}

impl SearchStats {
    /// Creates new zeroed statistics.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns the number of expanded nodes observed so far.
    #[must_use]
    pub fn expanded(&self) -> u64 {
        self.inner.expanded.load(Ordering::Relaxed)
    }

    /// Returns the number of generated successors observed so far (before
    /// duplicate filtering).
    #[must_use]
    pub fn generated(&self) -> u64 {
        self.inner.generated.load(Ordering::Relaxed)
    }
}

impl Observer for SearchStats {
    fn on_node_expanded(&mut self, _node: &Node) {
        self.inner.expanded.fetch_add(1, Ordering::Relaxed);
    }

    fn on_successor(&mut self, _parent: &Node, _child: &Node) {
        self.inner.generated.fetch_add(1, Ordering::Relaxed);
    }
}
