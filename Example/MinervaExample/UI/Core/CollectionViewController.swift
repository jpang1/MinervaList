//
//  CollectionViewController.swift
//  MinervaExample
//
//  Copyright © 2019 Optimize Fitness, Inc. All rights reserved.
//

import Foundation
import UIKit

import Minerva

import PromiseKit

protocol CollectionViewControllerDataSource {
  func loadSections() -> Promise<[ListSection]>
}

class CollectionViewController: UIViewController {

  var showBackButton = true
  var hasLargeTitle = false
  var isNavigationBarHidden = false
  var isTabBarHidden = false
  var rightBarButton: UIBarButtonItem?

  private let listController = ListController()

  private let collectionView: UICollectionView = {
    let layout = ListViewLayout(stickyHeaders: false, topContentInset: 0, stretchToEdge: true)
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
    collectionView.backgroundColor = .white
    return collectionView
  }()

  private let dataSource: CollectionViewControllerDataSource

  // MARK: - Lifecycle

  required init(dataSource: CollectionViewControllerDataSource) {
    self.dataSource = dataSource
    super.init(nibName: nil, bundle: nil)
    listController.viewController = self
    listController.sizeDelegate = self
    listController.collectionView = collectionView
  }

  @available(*, unavailable)
  required convenience init?(coder aDecoder: NSCoder) {
    fatalError("Unsupported")
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = rightBarButton

    view.backgroundColor = .white
    view.addSubview(collectionView)
    anchorViewToTopSafeAreaLayoutGuide(collectionView)
    view.shouldTranslateAutoresizingMaskIntoConstraints(false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tabBarHidden = isTabBarHidden
    navigationController?.isNavigationBarHidden = isNavigationBarHidden
    navigationController?.navigationBar.prefersLargeTitles = hasLargeTitle
    navigationController?.navigationBar.tintColor = .selectable
    loadModels(animated: true, completion: nil)
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    let context = collectionView.collectionViewLayout.invalidationContext(forBoundsChange: .zero)
    coordinator.animate(alongsideTransition: { [weak self] _ in
      self?.collectionView.collectionViewLayout.invalidateLayout(with: context)
    })
  }

  // MARK: - Public

  func loadModels(animated: Bool, completion: ((Bool) -> Void)?) {
    LoadingHUD.show(in: view)
    dataSource.loadSections().done { [weak self] sections in
      guard let strongSelf = self else { return }
      strongSelf.listController.update(with: sections, animated: animated, completion: completion)
    }.catch { [weak self] error in
      UIAlertController.display(
        error,
        defaultTitle: "Failed to load your data",
        parentVC: self
      )
    }.finally { [weak self] in
      LoadingHUD.hide(from: self?.view)
    }
  }
}


// MARK: - ListControllerSizeDelegate
extension CollectionViewController: ListControllerSizeDelegate {

  func listController(
    _ listController: ListController,
    sizeFor model: ListCellModel,
    at indexPath: IndexPath,
    constrainedTo sizeConstraints: ListSizeConstraints
  ) -> CGSize? {
    guard model is MarginCellModel else {
      return model.size(with: sizeConstraints)
    }

    let containerSize = sizeConstraints.containerSize

    if let size = model.size(constrainedTo: containerSize) {
      return size
    }

    let dynamicHeight = listController.listSections.reduce(containerSize.height, { sum, section -> CGFloat in
      let sectionHeight = section.height(for: sizeConstraints.containerSize) ?? 0
      return sum - sectionHeight
    })

    let height = max(20, dynamicHeight / 2)
    return CGSize(width: sizeConstraints.containerSizeAdjustedForInsets.width, height: height)
  }
}