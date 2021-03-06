Package: src/packages/rtl-threads.fdoc


=================================
Run Time Library Pthread support.
=================================


========================== ============================================
key                        file                                         
========================== ============================================
pthread_thread_control.cpp share/src/pthread/pthread_thread_control.cpp 
flx_ts_collector.hpp       share/lib/rtl/flx_ts_collector.hpp           
flx_ts_collector.cpp       share/src/pthread/flx_ts_collector.cpp       
flx_pthread.py             $PWD/buildsystem/flx_pthread.py              
flx_pthread_config.hpp     share/lib/rtl/flx_pthread_config.hpp         
========================== ============================================

==================== ====================================
key                  file                                 
==================== ====================================
unix_flx_pthread.fpc $PWD/src/config/unix/flx_pthread.fpc 
win_flx_pthread.fpc  $PWD/src/config/win/flx_pthread.fpc  
linux_pthread.fpc    $PWD/src/config/linux/pthread.fpc    
default_pthread.fpc  $PWD/src/config/pthread.fpc          
==================== ====================================


Thread Control
==============


.. code-block:: cpp

  //[pthread_thread_control.cpp]
  #include "pthread_thread.hpp"
  #include <stdio.h>
  #include <cstdlib>
  #include <cassert>
  
  #define FLX_SAVE_REGS \
    jmp_buf reg_save_on_stack; \
    setjmp (reg_save_on_stack)
  
  
  namespace flx { namespace pthread {
  
  world_stop_notifier_t::~world_stop_notifier_t(){}
  
  static void *get_stack_pointer() { 
    void *x; 
    void *y = (void*)&x;
    return y; 
  }
  
  // SHOULD BE MUTEX PROTECETD
  void thread_control_t::register_world_stop_notifier(world_stop_notifier_t *p)
  {
  //fprintf(stderr,"World stop notifier registered: %p\n", p);
    for (size_t i=0; i<world_stop_notifier_array_length; ++i)
      if(p == world_stop_notifier_array[i]) return;
    world_stop_notifier_array = (world_stop_notifier_t**)realloc(world_stop_notifier_array, 
      sizeof(world_stop_notifier_t*) * (world_stop_notifier_array_length + 1));
    world_stop_notifier_array[world_stop_notifier_array_length] = p;
    ++world_stop_notifier_array_length;
  }
  
  // SHOULD BE MUTEX PROTECETD
  void thread_control_t::unregister_world_stop_notifier(world_stop_notifier_t *p)
  {
    size_t i = 0;
    for (i=0; i<world_stop_notifier_array_length; ++i)
      if(p == world_stop_notifier_array[i]) break;
    if (i == world_stop_notifier_array_length) return;
    for (size_t j =  i + 1; j < world_stop_notifier_array_length; ++j)
      world_stop_notifier_array[j-1] = world_stop_notifier_array[j];
    --world_stop_notifier_array_length;
    world_stop_notifier_array = (world_stop_notifier_t**)realloc(world_stop_notifier_array,
      sizeof(world_stop_notifier_t*) * (world_stop_notifier_array_length));
  }
  
  void thread_control_t::world_stop_notify()
  {
  if (world_stop_notifier_array_length > 0)
    //fprintf(stderr, "thread_control_t::world_stop_notify() notifying %zu objects\n",
    //  world_stop_notifier_array_length);
    for (size_t i=0; i<world_stop_notifier_array_length; ++i)
      world_stop_notifier_array[i]->notify_world_stop();
  }
  
  bool thread_control_t::get_debug()const { return debug; }
  
  thread_control_base_t::~thread_control_base_t(){}
  
  thread_control_t::thread_control_t (bool d) :
    do_world_stop(false), thread_counter(0), active_counter(0), debug(d),
    world_stop_notifier_array(0), world_stop_notifier_array_length(0)
    {
      if(debug)
        fprintf(stderr,"INITIALISING THREAD CONTROL OBJECT\n");
    }
  
  size_t thread_control_t::thread_count()
    {
      ::std::unique_lock< ::std::mutex> m(stop_mutex);
      return thread_counter;
    }
  
  size_t thread_control_t::active_count()
    {
      ::std::unique_lock< ::std::mutex> m(stop_mutex);
      return active_counter;
    }
  
  void thread_control_t::add_thread(void *stack_base)
    {
      ::std::unique_lock< ::std::mutex> m(stop_mutex);
      uintptr_t id = mythrid();
      threads.insert (std::make_pair(id, thread_data_t (stack_base)));
      ++thread_counter;
      ++active_counter;
      if(debug)
        fprintf(stderr, "Adding thread %p base %p, count=%zu\n", (void*)(uintptr_t)id, stack_base, thread_counter);
      stop_guard.notify_all();
    }
  
  void thread_control_t::remove_thread()
    {
      ::std::unique_lock< ::std::mutex> m(stop_mutex);
      uintptr_t id = mythrid();
      if (threads.erase(id) == 0)
      {
        fprintf(stderr, "Remove thread %p which is not registered\n", (void*)(uintptr_t)id);
        std::abort();
      }
      --thread_counter;
      --active_counter;
      if(debug)
        fprintf(stderr, "Removed thread %p, count=%zu\n", (void*)(uintptr_t)id, thread_counter);
      stop_guard.notify_all();
    }
  
  // stop the world!
  
  // NOTE: ON EXIT, THE MUTEX REMAINS LOCKED
  
  bool thread_control_t::world_stop()
    {
      stop_mutex.lock();
      if(debug)
        fprintf(stderr,"Thread %p Stopping world, active threads=%zu\n", (void*)mythrid(), active_counter);
      if (do_world_stop) {
        stop_mutex.unlock();
        return false; // race! Someone else beat us
      }
      do_world_stop = true;
  
      // this calls the notify_world_stop() method of all the
      // objects such as condition variables that are registered
      // in the notification list. That method is expected to do a notify_all()
      // on the condition variable.
  
      world_stop_notify();
  
      // this is for the thread control objects own condition variable
      // which is used to count the number of threads that have suspended
  
      stop_guard.notify_all();
  
      while(active_counter>1) {
        if(debug)
          for(
            thread_registry_t::iterator it = threads.begin();
            it != threads.end();
            ++it
          )
          {
            fprintf(stderr, "Thread = %p is %s\n",(void*)(uintptr_t)(*it).first, (*it).second.active? "ACTIVE": "SUSPENDED");
          }
        if(debug)
          fprintf(stderr,"Thread %p Stopping world: begin wait, threads=%zu\n",  (void*)mythrid(), thread_counter);
        stop_guard.wait(stop_mutex);
        if(debug)
          fprintf(stderr,"Thread %p Stopping world: checking threads=%zu\n", (void*)mythrid(), thread_counter);
      }
      // this code has to be copied here, we cannot use 'yield' because
      // it would deadlock ourself
      {
        uintptr_t id = mythrid();
        FLX_SAVE_REGS;
        void *stack_pointer = get_stack_pointer();
        if(debug)
          fprintf(stderr,"World stop thread=%p, stack=%p!\n",(void*)(uintptr_t)id, stack_pointer);
        thread_registry_t::iterator it = threads.find(id);
        if(it == threads.end()) {
          fprintf(stderr,"MAIN THREAD: Cannot find thread %p in registry\n",(void*)(uintptr_t)id);
          abort();
        }
        (*it).second.stack_top = stack_pointer;
        if(debug)
          fprintf(stderr,"Stack size = %zu\n",(size_t)((char*)(*it).second.stack_base -(char*)(*it).second.stack_top));
      }
      if(debug)
        fprintf(stderr,"World STOPPED\n");
      return true; // we stopped the world
    }
  
  // used by mainline to wait for other threads to die
  void thread_control_t::join_all()
    {
      ::std::unique_lock< ::std::mutex> m(stop_mutex);
      if(debug)
        fprintf(stderr,"Thread %p Joining all\n", (void*)mythrid());
      while(do_world_stop || thread_counter>1) {
        unsafe_stop_check();
        stop_guard.wait(stop_mutex);
      }
      if(debug)
        fprintf(stderr,"World restarted: do_world_stop=%d, Yield thread count now %zu\n",do_world_stop,thread_counter);
    }
  
  // restart the world
  void thread_control_t::world_start()
    {
      if(debug)
        fprintf(stderr,"Thread %p Restarting world\n", (void*)mythrid());
      do_world_stop = false;
      stop_mutex.unlock();
      stop_guard.notify_all();
    }
  
  memory_ranges_t *thread_control_t::get_block_list()
  {
    memory_ranges_t *v = new std::vector<memory_range_t>;
    thread_registry_t::iterator end = threads.end();
    for(thread_registry_t::iterator i = threads.begin();
      i != end;
      ++i
    )
    {
      thread_data_t const &td = (*i).second;
      // !(base < top) means top <= base, i.e. stack grows downwards
      assert(!std::less<void*>()(td.stack_base,td.stack_top));
      // from top upto base..
      v->push_back(memory_range_t(td.stack_top, td.stack_base));
    }
    return v;
  }
  
  void thread_control_t::suspend()
  {
    ::std::unique_lock< ::std::mutex> m(stop_mutex);
    if(debug)
      fprintf(stderr,"[suspend: thread= %p]\n", (void*)mythrid());
    unsafe_suspend();
  }
  
  void thread_control_t::resume()
  {
    ::std::unique_lock< ::std::mutex> m(stop_mutex);
    if(debug)
      fprintf(stderr,"[resume: thread= %p]\n", (void*)mythrid());
    unsafe_resume();
  }
  
  
  void thread_control_t::unsafe_suspend()
  {
    void *stack_pointer = get_stack_pointer();
    uintptr_t id = mythrid();
    if(debug)
      fprintf(stderr,"[unsafe_suspend:thread=%p], stack=%p!\n",(void*)(uintptr_t)id, stack_pointer);
    thread_registry_t::iterator it = threads.find(id);
    if(it == threads.end()) {
      if(debug)
        fprintf(stderr,"[unsafe_suspend] Cannot find thread %p in registry\n",(void*)(uintptr_t)id);
        abort();
    }
    (*it).second.stack_top = stack_pointer;
    (*it).second.active = false;
    if(debug) // VC++ is bugged, doesn't support %td format correctly?
      fprintf(stderr,"[unsafe_suspend: thread=%p] stack base %p > stack top %p, Stack size = %zd\n",
        (void*)(uintptr_t)id,
        (char*)(*it).second.stack_base,
        (char*)(*it).second.stack_top, 
        (size_t)((char*)(*it).second.stack_base -(char*)(*it).second.stack_top));
    --active_counter;
    if(debug)
      fprintf(stderr,"[unsafe_suspend]: active thread count now %zu\n",active_counter);
    stop_guard.notify_all();
    if(debug)
      fprintf(stderr,"[unsafe_suspend]: stop_guard.notify_all() done");
  }
  
  void thread_control_t::unsafe_resume()
  {
    if(debug)
      fprintf(stderr,"[unsafe_resume: thread %p]\n", (void*)mythrid());
    stop_guard.notify_all();
    if(debug)
      fprintf(stderr,"[unsafe_resume]: stop_guard.notify_all() done");
    while(do_world_stop) stop_guard.wait(stop_mutex);
    if(debug)
      fprintf(stderr,"[unsafe_resume]: stop_guard.wait() done");
    ++active_counter;
    uintptr_t id = mythrid();
    thread_registry_t::iterator it = threads.find(id);
    if(it == threads.end()) {
      if(debug)
        fprintf(stderr,"[unsafe_resume: thread=%p] Cannot find thread in registry\n",(void*)(uintptr_t)id);
        abort();
    }
    (*it).second.active = true;
    if(debug) {
      fprintf(stderr,"[unsafe_resume: thread=%p] resumed, active count= %zu\n",
        (void*)mythrid(),active_counter);
    }
    stop_guard.notify_all();
    if(debug)
      fprintf(stderr,"[unsafe_resume]: stop_guard.notify_all() done");
  }
  
  // mutex already held
  void thread_control_t::unsafe_stop_check()
  {
  //fprintf(stderr, "Unsafe stop check ..\n");
    if (do_world_stop)
    {
  
      if(debug)
        fprintf(stderr,"[unsafe_stop_check: thread=%p] world_stop detected\n", 
          (void*)mythrid());
      FLX_SAVE_REGS;
      unsafe_suspend();
      unsafe_resume();
    }
  //fprintf(stderr, "Unsafe stop check finishes\n");
  }
  
  void thread_control_t::yield()
  {
  //fprintf(stderr,"Thread control yield starts\n");
    ::std::unique_lock< ::std::mutex> m(stop_mutex);
    if(debug)
      fprintf(stderr,"[Thread_control:yield: thread=%p]\n", (void*)mythrid());
  //fprintf(stderr,"Unsafe stop check starts\n");
    unsafe_stop_check();
  //fprintf(stderr,"Unsafe stop check done\n");
  }
  
  }}

Thread Safe Collector.
======================

The thread safe collector class  :code:`flx_ts_collector_t` is derived
from the  :code:`flx_collector_t` class. It basically dispatches to
its base with locks as required.


.. code-block:: cpp

  //[flx_ts_collector.hpp]
  
  #ifndef __FLX_TS_COLLECTOR_H__
  #define __FLX_TS_COLLECTOR_H__
  #include "flx_collector.hpp"
  #include "pthread_thread.hpp"
  #include <thread>
  #include <mutex>
  
  namespace flx {
  namespace gc {
  namespace collector {
  
  /// Naive thread safe Mark and Sweep Collector.
  struct PTHREAD_EXTERN flx_ts_collector_t :
    public flx::gc::collector::flx_collector_t
  {
    flx_ts_collector_t(allocator_t *, flx::pthread::thread_control_t *, int _gcthreads, FILE*);
    ~flx_ts_collector_t();
  
  private:
    /// allocator
    void *v_allocate(gc_shape_t *ptr_map, size_t);
  
    /// collector (returns number of objects collected)
    size_t v_collect();
  
    // add and remove roots
    void v_add_root(void *memory);
    void v_remove_root(void *memory);
  
    // statistics
    size_t v_get_allocation_count()const;
    size_t v_get_root_count()const;
    size_t v_get_allocation_amt()const;
  
  private:
    mutable ::std::mutex mut;
  };
  
  
  }}} // end namespaces
  
  #endif



.. code-block:: cpp

  //[flx_ts_collector.cpp]
  #include "flx_rtl_config.hpp"
  #include "flx_ts_collector.hpp"
  
  namespace flx {
  namespace gc {
  namespace collector {
  
  flx_ts_collector_t::flx_ts_collector_t(allocator_t *a, flx::pthread::thread_control_t *tc,int _gcthreads, FILE *tf) :
    flx_collector_t(a,tc,_gcthreads,tf)
  {}
  
  flx_ts_collector_t::~flx_ts_collector_t(){}
  
  void *flx_ts_collector_t::v_allocate(gc_shape_t *ptr_map, size_t x) {
    ::std::unique_lock< ::std::mutex> dummy(mut);
    return impl_allocate(ptr_map,x);
  }
  
  size_t flx_ts_collector_t::v_collect() {
    // NO MUTEX
    //if(debug)
    //  fprintf(stderr,"[gc] Request to collect, thread_control = %p, thread %p\n", thread_control, (size_t)flx::pthread::get_current_native_thread());
    return impl_collect();
  }
  
  void flx_ts_collector_t::v_add_root(void *memory) {
    ::std::unique_lock< ::std::mutex> dummy(mut);
    impl_add_root(memory);
  }
  
  void flx_ts_collector_t::v_remove_root(void *memory) {
    ::std::unique_lock< ::std::mutex> dummy(mut);
    impl_remove_root(memory);
  }
  
  size_t flx_ts_collector_t::v_get_allocation_count()const {
    ::std::unique_lock< ::std::mutex> dummy(mut);
    return impl_get_allocation_count();
  }
  
  size_t flx_ts_collector_t::v_get_root_count()const {
    ::std::unique_lock< ::std::mutex> dummy(mut);
    return impl_get_root_count();
  }
  
  size_t flx_ts_collector_t::v_get_allocation_amt()const {
    ::std::unique_lock< ::std::mutex> dummy(mut);
    return impl_get_allocation_amt();
  }
  
  
  }}} // end namespaces
  
  
Build System
============


.. code-block:: python

  #[flx_pthread.py]
  import fbuild
  from fbuild.functools import call
  from fbuild.path import Path
  from fbuild.record import Record
  from fbuild.builders.file import copy
  
  import buildsystem
  from buildsystem.config import config_call
  
  # ------------------------------------------------------------------------------
  
  def build_runtime(phase):
      print('[fbuild] [rtl] build pthread')
      path = Path(phase.ctx.buildroot/'share'/'src/pthread')
  
      srcs = Path.glob(path / '*.cpp')
      includes = [
        phase.ctx.buildroot / 'host/lib/rtl', 
        phase.ctx.buildroot / 'share/lib/rtl']
      macros = ['BUILD_PTHREAD']
      flags = []
      libs = [
          call('buildsystem.flx_gc.build_runtime', phase),
      ]
      external_libs = []
  
      pthread_h = config_call('fbuild.config.c.posix.pthread_h',
          phase.platform,
          phase.cxx.shared)
  
      dst = 'host/lib/rtl/flx_pthread'
      if pthread_h.pthread_create:
          flags.extend(pthread_h.flags)
          libs.extend(pthread_h.libs)
          external_libs.extend(pthread_h.external_libs)
  
      return Record(
          static=buildsystem.build_cxx_static_lib(phase, dst, srcs,
              includes=includes,
              macros=macros,
              cflags=flags,
              libs=[lib.static for lib in libs],
              external_libs=external_libs,
              lflags=flags),
          shared=buildsystem.build_cxx_shared_lib(phase, dst, srcs,
              includes=includes,
              macros=macros,
              cflags=flags,
              libs=[lib.shared for lib in libs],
              external_libs=external_libs,
              lflags=flags))
  


Configuration Database
======================


.. code-block:: fpc

  //[unix_flx_pthread.fpc]
  Name: Flx_pthread
  Description: Felix Pre-emptive threading support
  
  provides_dlib: -lflx_pthread_dynamic
  provides_slib: -lflx_pthread_static
  includes: '"pthread_thread.hpp"'
  Requires: flx_gc flx_exceptions pthread
  library: flx_pthread
  macros: BUILD_PTHREAD
  srcdir: src/pthread
  src: .*\.cpp


.. code-block:: fpc

  //[win_flx_pthread.fpc]
  Name: Flx_pthread
  Description: Felix Pre-emptive threading support
  
  provides_dlib: /DEFAULTLIB:flx_pthread_dynamic
  provides_slib: /DEFAULTLIB:flx_pthread_static
  includes: '"pthread_thread.hpp"'
  Requires: flx_gc flx_exceptions pthread
  library: flx_pthread
  macros: BUILD_PTHREAD
  srcdir: src/pthread
  src: .*\.cpp


.. code-block:: fpc

  //[default_pthread.fpc]
  Description: pthread support defaults to no requirements


.. code-block:: fpc

  //[linux_pthread.fpc]
  Description: Linux pthread support
  requires_dlibs: -lpthread
  requires_slibs: -lpthread



.. code-block:: cpp

  //[flx_pthread_config.hpp]
  #ifndef __FLX_PTHREAD_CONFIG_H__
  #define __FLX_PTHREAD_CONFIG_H__
  #include "flx_rtl_config.hpp"
  #ifdef BUILD_PTHREAD
  #define PTHREAD_EXTERN FLX_EXPORT
  #else
  #define PTHREAD_EXTERN FLX_IMPORT
  #endif
  #endif



