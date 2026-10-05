use std::{
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    thread,
};

use soukoban::{prelude::*, solver::Solver};

use crate::enums::{algorithm::Algorithm, strategy::Strategy};

/// Solver thread stack size in bytes (64 MB).
const SOLVER_STACK_SIZE: usize = 64 * 1024 * 1024;

pub struct SolverWorker {
    /// Active solver instance.
    solver: Option<Solver>,
    /// Shared storage for the background solver result.
    result: Arc<Mutex<Option<Result<Actions, SearchError>>>>,
    /// Flag indicating that the solver thread has finished.
    done: Arc<AtomicBool>,
    /// Handle to the solver thread.
    handle: Option<thread::JoinHandle<()>>,
}

impl SolverWorker {
    pub fn new() -> Self {
        Self {
            solver: None,
            result: Arc::new(Mutex::new(None)),
            done: Arc::new(AtomicBool::new(false)),
            handle: None,
        }
    }

    /// Starts solving in a background thread with a custom stack size.
    pub fn start(&mut self, map: Map, algorithm: Algorithm, strategy: Strategy) {
        self.cancel();

        let result_slot = Arc::clone(&self.result);
        let done_flag = Arc::clone(&self.done);

        done_flag.store(false, Ordering::Release);
        *result_slot.lock().unwrap() = None;

        let solver = Solver::new(map, strategy.into());
        self.solver = Some(solver.clone());

        let handle = thread::Builder::new()
            .name("solver".into())
            .stack_size(SOLVER_STACK_SIZE)
            .spawn(move || {
                let result = solver.search(algorithm.into());
                *result_slot.lock().unwrap() = Some(result);
                done_flag.store(true, Ordering::Release);
            })
            .expect("failed to spawn solver thread");

        self.handle = Some(handle);
    }

    /// Polls for the solver result. Returns `Some` if the solver finished, otherwise `None`.
    pub fn poll(&mut self) -> Option<Result<Actions, SearchError>> {
        if !self.done.load(Ordering::Acquire) {
            return None;
        }

        if let Some(handle) = self.handle.take() {
            let _ = handle.join();
        }
        self.solver = None;

        self.result.lock().unwrap().take()
    }

    /// Cancels a running solve (if any).
    pub fn cancel(&mut self) {
        if let Some(solver) = self.solver.take() {
            solver.request_stop();
        }
        if let Some(handle) = self.handle.take() {
            // Wait for the solver thread to exit.
            let _ = handle.join();
            self.done.store(false, Ordering::Release);
            *self.result.lock().unwrap() = None;
        }
    }
}
