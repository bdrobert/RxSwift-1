//
//  Catch.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/19/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

class Catch_Impl<ElementType> : ObserverType {
    typealias Element = ElementType
    typealias Parent = Catch_<Element>
    
    let parent: Parent
    
    init(parent: Parent) {
        self.parent = parent
    }
    
    func on(event: Event<ElementType>) {
        parent.observer.on(event)
        
        switch event {
        case .Next:
            break
        case .Error:
            parent.dispose()
        case .Completed:
            parent.dispose()
        }
    }
}

class Catch_<ElementType> : Sink<ElementType>, ObserverType {
    typealias Element = ElementType
    typealias Parent = Catch<Element>
    
    let parent: Parent
    let subscription = SerialDisposable()
    
    init(parent: Parent, observer: ObserverOf<Element>, cancel: Disposable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        let disposableSubscription = parent.source.subscribe(self)
        subscription.setDisposable(disposableSubscription)
        
        return subscription
    }
    
    func on(event: Event<Element>) {
        switch event {
        case .Next:
            self.observer.on(event)
        case .Completed:
            self.observer.on(event)
            self.dispose()
        case .Error(let error):
            parent.handler(error).recoverWith { error2 in
                sendError(observer, error2)
                self.dispose()
                return failure(error2)
            }.flatMap { catchObservable -> RxResult<Void> in
                let d = SingleAssignmentDisposable()
                subscription.setDisposable(d)
                
                let observer = Catch_Impl(parent: self)
                
                let subscription2 = catchObservable.subscribe(observer)
                d.setDisposable(subscription2)
                return SuccessResult
            }
        }
    }
}

class Catch<Element> : Producer<Element> {
    typealias Handler = (ErrorType) -> RxResult<Observable<Element>>
    
    let source: Observable<Element>
    let handler: Handler
    
    init(source: Observable<Element>, handler: Handler) {
        self.source = source
        self.handler = handler
    }
    
    override func run(observer: ObserverOf<Element>, cancel: Disposable, setSink: (Disposable) -> Void) -> Disposable {
        let sink = Catch_(parent: self, observer: observer, cancel: cancel)
        setSink(sink)
        return sink.run()
    }
}

class CatchToResult_<ElementType> : Sink <RxResult<ElementType>>, ObserverType {
    typealias Element = ElementType
    typealias Parent = CatchToResult<ElementType>
    
    let parent: Parent
    
    init(parent: Parent, observer: ObserverOf <RxResult<ElementType>>, cancel: Disposable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        return parent.source.subscribe(self)
    }
    
    func on(event: Event<Element>) {
        switch event {
        case .Next(let boxedValue):
            let value = boxedValue.value
            sendNext(observer, success(value))
        case .Completed:
            sendCompleted(observer)
            self.dispose()
        case .Error(let error):
            sendNext(observer, failure(error))
            sendCompleted(observer)
            self.dispose()
        }
    }
}

class CatchToResult<Element> : Producer <RxResult<Element>> {
    let source: Observable<Element>
    
    init(source: Observable<Element>) {
        self.source = source
    }
    
    override func run(observer: ObserverOf <RxResult<Element>>, cancel: Disposable, setSink: (Disposable) -> Void) -> Disposable {
        let sink = CatchToResult_(parent: self, observer: observer, cancel: cancel)
        setSink(sink)
        return sink.run()
    }
}