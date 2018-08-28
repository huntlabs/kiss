/*
 * Kiss - A refined core library for D programming language.
 *
 * Copyright (C) 2015-2018  Shanghai Putao Technology Co., Ltd
 *
 * Developer: HuntLabs.cn
 *
 * Licensed under the Apache-2.0 License.
 *
 */
 
module kiss.event.selector.iocp;

// dfmt off
version (Windows) : 
// dfmt on

import kiss.event.socket;

import kiss.event.core;
import kiss.event.socket.iocp;
import kiss.event.timer;

import core.sys.windows.windows;
import std.conv;
import kiss.logger;

/**
*/
class AbstractSelector : Selector
{
    this()
    {
        _iocpHandle = CreateIoCompletionPort(INVALID_HANDLE_VALUE, null, 0, 0);
        _event = new EventChannel(this);
        _timer.init();
    }

    ~this()
    {
        // .close(_iocpHandle);
    }

    override bool register(AbstractChannel watcher)
    {
        assert(watcher !is null);

        if (watcher.type == WatcherType.Timer)
        {
            AbstractTimer wt = cast(AbstractTimer) watcher;
            assert(wt !is null);
            if (wt is null || !wt.setTimerOut())
                return false;
            _timer.timeWheel().addNewTimer(wt.timer, wt.wheelSize());
        }
        else if (watcher.type == WatcherType.TCP
                || watcher.type == WatcherType.Accept 
                || watcher.type == WatcherType.UDP)
        {
            version (KissDebugMode)
                trace("Run CreateIoCompletionPort on socket: ", watcher.handle);
            CreateIoCompletionPort(cast(HANDLE) watcher.handle, _iocpHandle,
                    cast(size_t)(cast(void*) watcher), 0);
        }

        version (KissDebugMode)
            infof("register, watcher(fd=%d, type=%s)", watcher.handle, watcher.type);
        _event.setNext(watcher);
        return true;
    }

    override bool reregister(AbstractChannel watcher)
    {
        throw new LoopException("The IOCP does not support reregister!");
    }

    override bool deregister(AbstractChannel watcher)
    {
        // FIXME: Needing refactor or cleanup -@Administrator at 8/28/2018, 3:28:18 PM
        // https://stackoverflow.com/questions/6573218/removing-a-handle-from-a-i-o-completion-port-and-other-questions-about-iocp
        //tracef("deregister (fd=%d)", watcher.handle);

        // IocpContext _data;
        // _data.watcher = watcher;
        // _data.operation = IocpOperation.close;
        // PostQueuedCompletionStatus(_iocpHandle, 0, 0, &_data.overlapped);

        return true;
    }

    void weakUp()
    {
        IocpContext _data;
        _data.watcher = _event;
        _data.operation = IocpOperation.event;

        PostQueuedCompletionStatus(_iocpHandle, 0, 0, &_data.overlapped);
    }

    void onLoop(scope void delegate() handler)
    {
        _runing = true;
        _timer.init();
        do
        {
            handler();
            handleSocketEvent();
        }
        while (_runing);
    }

    private void handleSocketEvent()
    {
        auto timeout = _timer.doWheel();
        OVERLAPPED* overlapped;
        ULONG_PTR key = 0;
        DWORD bytes = 0;

        debug
        {
            // const int ret = GetQueuedCompletionStatus(_iocpHandle, &bytes,
            //         &key, &overlapped, INFINITE);
            // tracef("GetQueuedCompletionStatus, ret=%d", ret);

            // trace("timeout=", timeout);
            const int ret = GetQueuedCompletionStatus(_iocpHandle, &bytes,
                    &key, &overlapped, timeout);
        }
        else
        {
            const int ret = GetQueuedCompletionStatus(_iocpHandle, &bytes,
                    &key, &overlapped, timeout);
        }

        IocpContext* ev = cast(IocpContext*) overlapped;
        if (ret == 0)
        {
            const auto erro = GetLastError();
            if (erro == WAIT_TIMEOUT) // || erro == ERROR_OPERATION_ABORTED
                return;

            error("error occurred, code=", erro);
            if (ev !is null) {
                AbstractChannel channel = ev.watcher;
                if(channel !is null && !channel.isClosed())
                    channel.close();
            } 
            return;
        }

        if (ev is null || ev.watcher is null)
            warning("ev is null or ev.watche is null");
        else
            handleIocpOperation(ev.operation, ev.watcher, bytes);
    }

    private void handleIocpOperation(IocpOperation op, AbstractChannel channel, DWORD bytes) {

        version (KissDebugMode)
            trace("ev.operation: ", op);

        switch (op)
        {
        case IocpOperation.accept:
            channel.onRead();
            break;
        case IocpOperation.connect:
            onSocketRead(channel, 0);
            break;
        case IocpOperation.read:
            onSocketRead(channel, bytes);
            break;
        case IocpOperation.write:
            onSocketWrite(channel, bytes);
            break;
        case IocpOperation.event:
            channel.onRead();
            break;
        case IocpOperation.close:
            warning("close: ", );
            break;
        default:
            warning("unsupported operation type: ", op);
            break;
        }
    }

    override void stop()
    {
        _runing = false;
        weakUp();
    }

    void handleTimer()
    {

    }

    void dispose()
    {

    }

    private void onSocketRead(AbstractChannel wt, size_t len)
    {
        debug if(wt is null) {
            warning("channel is null");
            return;
        }

        if(len == 0 || wt.isClosed) {
            version (KissDebugMode) info("channel closed");
            return;
        }

        AbstractSocketChannel io = cast(AbstractSocketChannel) wt;
        // assert(io !is null, "The type of channel is: " ~ typeid(wt).name);
        if (io is null) {
            warning("The channel socket is null: ");
            return;
        }
        io.setRead(len);
        wt.onRead();
    }

    private void onSocketWrite(AbstractChannel wt, size_t len)
    {
        debug if(wt is null) {
            warning("channel is null");
            return;
        }
        AbstractStream client = cast(AbstractStream) wt;
        // assert(client !is null, "The type of channel is: " ~ typeid(wt).name);
        if (client is null) {
            warning("The channel socket is null: ");
            return;
        }
        client.onWriteDone(len); // Notify the client about how many bytes actually sent.
    }

private:
    bool _runing;
    HANDLE _iocpHandle;
    EventChannel _event;
    CustomTimer _timer;
}
