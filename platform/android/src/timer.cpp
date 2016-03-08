#include "run_loop_impl.hpp"

#include <mbgl/util/run_loop.hpp>
#include <mbgl/util/timer.hpp>

#include <functional>

namespace mbgl {
namespace util {

class Timer::Impl : public RunLoop::Impl::Runnable {
public:
    Impl() {
        loop->initRunnable(this);
    }

    ~Impl() {
        stop();
    }

    void start(Duration timeout, Duration repeat_, std::function<void ()>&& task_) {
        stop();

        repeat = repeat_;
        task = std::move(task_);
        due = Clock::now() + timeout;

        loop->addRunnable(this);
    }

    void stop() {
        task = nullptr;
        loop->removeRunnable(this);
    }

    void reschedule() {
        if (repeat != Duration::zero()) {
            due = Clock::now() + repeat;

            // Won't really re-add, but it will
            // wake up the main loop to update
            // the sleep timeout.
            loop->addRunnable(this);
        } else {
            stop();
        }
    }

    TimePoint dueTime() const override {
        return due;
    }

    void runTask() override {
        task();
        reschedule();
    }

private:
    TimePoint due;
    Duration repeat;

    RunLoop::Impl* loop = reinterpret_cast<RunLoop::Impl*>(RunLoop::getLoopHandle());

    std::function<void()> task;
};

Timer::Timer()
    : impl(std::make_unique<Impl>()) {
}

Timer::~Timer() = default;

void Timer::start(Duration timeout, Duration repeat, std::function<void()>&& cb) {
    impl->start(timeout, repeat, std::move(cb));
}

void Timer::stop() {
    impl->stop();
}

} // namespace util
} // namespace mbgl
