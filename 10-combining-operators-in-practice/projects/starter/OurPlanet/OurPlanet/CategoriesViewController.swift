/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import RxSwift
import RxCocoa

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  let categories = BehaviorRelay<[EOCategory]>(value: [])
  let disposeBag = DisposeBag()
  let loadingView: UIActivityIndicatorView = {
    let activity = UIActivityIndicatorView()
    activity.tintColor = UIColor.systemPurple
    return activity
  }()
  let downloadView = DownloadView()
  

  @IBOutlet var tableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    let loadingItem = UIBarButtonItem(customView: loadingView)
    navigationItem.setRightBarButton(loadingItem, animated: false)
    loadingView.startAnimating()
    loadingView.hidesWhenStopped = true

    view.addSubview(downloadView)
    view.layoutIfNeeded()

    categories
      .asObservable()
      .subscribe(onNext: { [weak self] _ in
        DispatchQueue.main.async {
          self?.tableView?.reloadData()
        }
      })
      .disposed(by: disposeBag)
    startDownload()
  }

  func startDownload() {
    // CHALLENGE 2
    downloadView.progress.progress = 0.0
    downloadView.label.text = "Download: 0%"

    let eoCategories = EONET.categories
    let downloadedEvents = eoCategories
      .flatMap { categories in
        return Observable.from(categories.map { category in
          EONET.events(forLast: 360, category: category)
        })
      }
      .merge(maxConcurrent: 2)

    let updatedCategories = eoCategories.flatMap { categories in
      downloadedEvents.scan((0,categories)) { tuple, events in
        return (tuple.0 + 1, tuple.1.map { category in
          let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
          if !eventsForCategory.isEmpty {
            var cat = category
            cat.events = cat.events + eventsForCategory
            return cat
          }
          return category
        })
      }
    }
    // CHALLENGE 1
    .do(onCompleted: { [weak self] in
      DispatchQueue.main.async {
        self?.loadingView.stopAnimating()
        self?.downloadView.isHidden = true  // CHALLENGE 2
      }
    })
    // CHALLENGE 2
    .do(onNext: { [weak self] tuple in
      DispatchQueue.main.async {
        let progress = Float(tuple.0) / Float(tuple.1.count)
        self?.downloadView.progress.progress = progress
        let percent = Int(progress * 100.0)
        self?.downloadView.label.text = "Download: \(percent)%"
      }
    })

    eoCategories
      .concat(updatedCategories.map(\.1)) // CHALLENGE 2
      .bind(to: categories)
      .disposed(by: disposeBag)
  }
  
  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    let category = categories.value[indexPath.row]
    cell.textLabel?.text = "\(category.name) (\(category.events.count))"
    cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator : .none
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = categories.value[indexPath.row]
    tableView.deselectRow(at: indexPath, animated: true)

    guard !category.events.isEmpty else { return }

    let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
    eventsController.title = category.name
    eventsController.events.accept(category.events)
    navigationController!.pushViewController(eventsController, animated: true)
  }
}

