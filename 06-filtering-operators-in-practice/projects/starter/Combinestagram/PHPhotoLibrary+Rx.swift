//
//  PHPhotoLibrary+Rx.swift
//  Combinestagram
//
//  Created by Javier Castañeda on 23/03/21.
//  Copyright © 2021 Underplot ltd. All rights reserved.
//

import Foundation
import Photos
import RxSwift

extension PHPhotoLibrary {
  static var authorized: Observable<Bool> {
    return Observable.create { observer in
      DispatchQueue.main.async {
        if authorizationStatus() == .authorized {
          observer.onNext(true)
          observer.onCompleted()
        } else {
          observer.onNext(false)
          requestAuthorization { status in
            observer.onNext(status == .authorized)
            observer.onCompleted()
          }
        }
      }
      return Disposables.create()
    }
  }
}
