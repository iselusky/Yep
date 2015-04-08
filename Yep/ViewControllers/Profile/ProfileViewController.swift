//
//  ProfileViewController.swift
//  Yep
//
//  Created by NIX on 15/3/16.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Realm

let YepUpdatedProfileAvatarNotification = "YepUpdatedProfileAvatarNotification"
let profileAvatarAspectRatio: CGFloat = 12.0 / 16.0

class ProfileViewController: UIViewController {

    @IBOutlet weak var profileCollectionView: UICollectionView!

    let skillRanckCellIdentifier = "SkillRankCell"
    let headerCellIdentifier = "ProfileHeaderCell"
    let footerCellIdentifier = "ProfileFooterCell"
    let sectionHeaderIdentifier = "ProfileSectionHeaderReusableView"
    let sectionFooterIdentifier = "ProfileSectionFooterReusableView"

    lazy var collectionViewWidth: CGFloat = {
        return CGRectGetWidth(self.profileCollectionView.bounds)
        }()
    lazy var sectionLeftEdgeInset: CGFloat = { return 20 }()
    lazy var sectionRightEdgeInset: CGFloat = { return 20 }()
    lazy var sectionBottomEdgeInset: CGFloat = { return 20 }()

    lazy var cellWidth: CGFloat = {
        return (self.collectionViewWidth - (self.sectionLeftEdgeInset + self.sectionRightEdgeInset)) / 3
        }()
    let cellHeight: CGFloat = 40


    let introductionText = "I would like to learn Design or Speech, I can teach you iOS Dev in return. 😃"

    let masterSkills = [
        ["skill":"iOS Dev", "rank":3],
        ["skill":"Linux", "rank":2],
        ["skill":"Cook", "rank":1],
    ]

    let learningSkills = [
        ["skill":"Design", "rank":1],
        ["skill":"Speech", "rank":0],
    ]

    lazy var footerCellHeight: CGFloat = {
        let attributes = [NSFontAttributeName: profileIntroductionLabelFont]
        let labelWidth = self.collectionViewWidth - (profileIntroductionLabelLeadingSpaceToContainer + profileIntroductionLabelTrailingSpaceToContainer)
        let rect = self.introductionText.boundingRectWithSize(CGSize(width: labelWidth, height: CGFloat(FLT_MAX)), options: .UsesLineFragmentOrigin | .UsesFontLeading, attributes:attributes, context:nil)
        return ceil(rect.height) + 4
        }()

    override func viewDidLoad() {
        super.viewDidLoad()

        profileCollectionView.registerNib(UINib(nibName: skillRanckCellIdentifier, bundle: nil), forCellWithReuseIdentifier: skillRanckCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: headerCellIdentifier, bundle: nil), forCellWithReuseIdentifier: headerCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: footerCellIdentifier, bundle: nil), forCellWithReuseIdentifier: footerCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: sectionHeaderIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: sectionHeaderIdentifier)
        profileCollectionView.registerClass(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: sectionFooterIdentifier)

        profileCollectionView.alwaysBounceVertical = true
        
        self.automaticallyAdjustsScrollViewInsets = false

        if let tabBarController = tabBarController {
            profileCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: CGRectGetHeight(tabBarController.tabBar.bounds), right: 0)
        }

        if let navigationController = navigationController {
            navigationController.navigationBar.backgroundColor = UIColor.clearColor()
            navigationController.navigationBar.translucent = true
            navigationController.navigationBar.shadowImage = UIImage()
            navigationController.navigationBar.barStyle = UIBarStyle.BlackTranslucent
            navigationController.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
        }
        
        let textAttributes = [
            NSForegroundColorAttributeName: UIColor.whiteColor(),
            NSFontAttributeName: UIFont(name: "HelveticaNeue-CondensedBlack", size: 20)!
        ]
        
        self.navigationController?.navigationBar.titleTextAttributes = textAttributes
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
}

// MARK: UIImagePicker

extension ProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        s3PublicUploadParams(failureHandler: nil) { s3UploadParams in

            dispatch_async(dispatch_get_main_queue()) {
                if let cell = self.profileCollectionView.cellForItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0)) as? ProfileHeaderCell {
                    cell.avatarImageView.image = image
                }
            }

            let image = image.largestCenteredSquareImage().resizeToTargetSize(YepConfig.avatarMaxSize())

            var imageData = UIImageJPEGRepresentation(image, YepConfig.avatarCompressionQuality())

            uploadFileToS3(inFilePath: nil, orFileData: imageData, mimeType: "image/jpeg", s3UploadParams: s3UploadParams, completion: { (result, error) in
                println("upload avatar to s3 result: \(result), error: \(error)")

                if (result) {
                    let newAvatarURLString = "\(s3UploadParams.url)\(s3UploadParams.key)"

                    updateMyselfWithInfo(["avatar_url": newAvatarURLString], failureHandler: nil) { success in
                        dispatch_async(dispatch_get_main_queue()) {
                            YepUserDefaults.setAvatarURLString(newAvatarURLString)

                            if
                                let myUserID = YepUserDefaults.userID(),
                                let me = userWithUserID(myUserID) {
                                    let realm = RLMRealm.defaultRealm()
                                    realm.beginWriteTransaction()
                                    me.avatarURLString = newAvatarURLString
                                    realm.commitWriteTransaction()
                            }

                            NSNotificationCenter.defaultCenter().postNotificationName(YepUpdatedProfileAvatarNotification, object: nil)
                        }
                    }
                }
            })
        }

        dismissViewControllerAnimated(true, completion: nil)
    }
}

// MARK: UICollectionView

extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    enum ProfileSection: Int {
        case Header = 0
        case Master
        case Learning
        case Footer
    }

    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 4
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        switch section {

        case ProfileSection.Header.rawValue:
            return 1

        case ProfileSection.Master.rawValue:
            return 3

        case ProfileSection.Learning.rawValue:
            return 2

        case ProfileSection.Footer.rawValue:
            return 1

        default:
            return 0
        }
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

        switch indexPath.section {

        case ProfileSection.Header.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(headerCellIdentifier, forIndexPath: indexPath) as! ProfileHeaderCell

            cell.nameLabel.text = YepUserDefaults.nickname()

            cell.changeAvatarAction = {

                let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)

                let choosePhotoAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Choose Photo", comment: ""), style: .Default) { action -> Void in
                    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.SavedPhotosAlbum) {
                        let imagePicker = UIImagePickerController()
                        imagePicker.delegate = self
                        imagePicker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum
                        imagePicker.allowsEditing = false

                        self.presentViewController(imagePicker, animated: true, completion: nil)
                    }
                }
                alertController.addAction(choosePhotoAction)

                let takePhotoAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Take Photo", comment: ""), style: .Default) { action -> Void in
                    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera){
                        let imagePicker = UIImagePickerController()
                        imagePicker.delegate = self
                        imagePicker.sourceType = UIImagePickerControllerSourceType.Camera
                        imagePicker.allowsEditing = false

                        self.presentViewController(imagePicker, animated: true, completion: nil)
                    }
                }
                alertController.addAction(takePhotoAction)

                let cancelAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel) { action -> Void in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
                alertController.addAction(cancelAction)

                self.presentViewController(alertController, animated: true, completion: nil)
            }

            return cell

        case ProfileSection.Master.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(skillRanckCellIdentifier, forIndexPath: indexPath) as! SkillRankCell

            cell.rankView.barColor = UIColor.skillMasterColor()

            let skillInfo = masterSkills[indexPath.row % masterSkills.count]
            cell.skillLabel.text = skillInfo["skill"] as? String
            cell.rankView.rank = skillInfo["rank"] as! Int

            return cell

        case ProfileSection.Learning.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(skillRanckCellIdentifier, forIndexPath: indexPath) as! SkillRankCell

            cell.rankView.barColor = UIColor.skillLearningColor()

            let skillInfo = learningSkills[indexPath.row % learningSkills.count]
            cell.skillLabel.text = skillInfo["skill"] as? String
            cell.rankView.rank = skillInfo["rank"] as! Int

            return cell

        case ProfileSection.Footer.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(footerCellIdentifier, forIndexPath: indexPath) as! ProfileFooterCell

            cell.introductionLabel.text = introductionText

            return cell

        default:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(skillRanckCellIdentifier, forIndexPath: indexPath) as! SkillRankCell

            return cell
        }
    }

    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {

        if kind == UICollectionElementKindSectionHeader {

            let header = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: sectionHeaderIdentifier, forIndexPath: indexPath) as! ProfileSectionHeaderReusableView

            switch indexPath.section {

            case ProfileSection.Header.rawValue:
                header.titleLabel.text = ""

            case ProfileSection.Master.rawValue:
                header.titleLabel.text = NSLocalizedString("Master", comment: "")

            case ProfileSection.Learning.rawValue:
                header.titleLabel.text = NSLocalizedString("Learning", comment: "")

            case ProfileSection.Footer.rawValue:
                header.titleLabel.text = NSLocalizedString("Introduction", comment: "")

            default:
                header.titleLabel.text = ""
            }

            return header

        } else {
            let footer = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: sectionFooterIdentifier, forIndexPath: indexPath) as! UICollectionReusableView
            return footer
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {

        switch section {

        case ProfileSection.Header.rawValue:
            return UIEdgeInsets(top: 0, left: 0, bottom: sectionBottomEdgeInset, right: 0)

        case ProfileSection.Master.rawValue:
            return UIEdgeInsets(top: 0, left: sectionLeftEdgeInset, bottom: sectionBottomEdgeInset, right: sectionRightEdgeInset)

        case ProfileSection.Learning.rawValue:
            return UIEdgeInsets(top: 0, left: sectionLeftEdgeInset, bottom: sectionBottomEdgeInset, right: sectionRightEdgeInset)

        case ProfileSection.Footer.rawValue:
            return UIEdgeInsets(top: 0, left: 0, bottom: sectionBottomEdgeInset, right: 0)

        default:
            return UIEdgeInsetsZero
        }
    }

    func collectionView(collectionView: UICollectionView!, layout collectionViewLayout: UICollectionViewLayout!, sizeForItemAtIndexPath indexPath: NSIndexPath!) -> CGSize {

        switch indexPath.section {

        case ProfileSection.Header.rawValue:
            return CGSizeMake(collectionViewWidth, collectionViewWidth * profileAvatarAspectRatio)

        case ProfileSection.Master.rawValue:
            return CGSizeMake(cellWidth, cellHeight)

        case ProfileSection.Learning.rawValue:
            return CGSizeMake(cellWidth, cellHeight)

        case ProfileSection.Footer.rawValue:
            return CGSizeMake(collectionViewWidth, footerCellHeight)

        default:
            return CGSizeZero
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

        if section == ProfileSection.Header.rawValue {
            return CGSizeMake(collectionViewWidth, 0)

        } else {
            return CGSizeMake(collectionViewWidth, cellHeight)
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSizeMake(collectionViewWidth, 0)
    }
}


