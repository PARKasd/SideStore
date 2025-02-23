//
//  StoreApp.swift
//  AltStore
//
//  Created by Riley Testut on 5/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas
import AltSign

public extension StoreApp
{
    #if ALPHA
    static let altstoreAppID = "com.SideStore.SideStore"
    #elseif BETA
    static let altstoreAppID = "com.SideStore.SideStore"
    #else
    static let altstoreAppID = "com.SideStore.SideStore"
    #endif
    
    static let dolphinAppID = "me.oatmealdome.dolphinios-njb"
}

@objc
public enum Platform: UInt {
    case ios
    case tvos
    case macos
}

extension Platform: Decodable {}

@objc
public final class PlatformURL: NSManagedObject, Decodable {
    /* Properties */
    @NSManaged public private(set) var platform: Platform
    @NSManaged public private(set) var downloadURL: URL
    
    
    private enum CodingKeys: String, CodingKey
    {
        case platform
        case downloadURL
    }
    
    
    public init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { preconditionFailure("Decoder must have non-nil NSManagedObjectContext.") }
        
        // Must initialize with context in order for child context saves to work correctly.
        super.init(entity: PlatformURL.entity(), insertInto: context)
        
        do
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.platform = try container.decode(Platform.self, forKey: .platform)
            self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        }
        catch
        {
            if let context = self.managedObjectContext
            {
                context.delete(self)
            }
            
            throw error
        }
    }
}

extension PlatformURL: Comparable {
    public static func < (lhs: PlatformURL, rhs: PlatformURL) -> Bool {
        return lhs.platform.rawValue < rhs.platform.rawValue
    }
    
    public static func > (lhs: PlatformURL, rhs: PlatformURL) -> Bool {
        return lhs.platform.rawValue > rhs.platform.rawValue
    }
    
    public static func <= (lhs: PlatformURL, rhs: PlatformURL) -> Bool {
        return lhs.platform.rawValue <= rhs.platform.rawValue
    }
    
    public static func >= (lhs: PlatformURL, rhs: PlatformURL) -> Bool {
        return lhs.platform.rawValue >= rhs.platform.rawValue
    }
}

public typealias PlatformURLs = [PlatformURL]

@objc(StoreApp)
public class StoreApp: NSManagedObject, Decodable, Fetchable
{
    /* Properties */
    @NSManaged public private(set) var name: String
    @NSManaged public private(set) var bundleIdentifier: String
    @NSManaged public private(set) var subtitle: String?
    
    @NSManaged public private(set) var developerName: String
    @NSManaged public private(set) var localizedDescription: String
    @NSManaged public private(set) var size: Int32
    
    @NSManaged public private(set) var iconURL: URL
    @NSManaged public private(set) var screenshotURLs: [URL]
    
    @NSManaged public var version: String
    @NSManaged public private(set) var versionDate: Date
    @NSManaged public private(set) var versionDescription: String?
    
    @NSManaged public private(set) var downloadURL: URL
    @NSManaged public private(set) var platformURLs: PlatformURLs?

    @NSManaged public private(set) var tintColor: UIColor?
    @NSManaged public private(set) var isBeta: Bool
    
    @NSManaged public var sourceIdentifier: String?
    
    @NSManaged public var sortIndex: Int32
    
    /* Relationships */
    @NSManaged public var installedApp: InstalledApp?
    @NSManaged public var newsItems: Set<NewsItem>
    
    @NSManaged @objc(source) public var _source: Source?
    @NSManaged @objc(permissions) public var _permissions: NSOrderedSet
    
    @nonobjc public var source: Source? {
        set {
            self._source = newValue
            self.sourceIdentifier = newValue?.identifier
        }
        get {
            return self._source
        }
    }
    
    @nonobjc public var permissions: [AppPermission] {
        return self._permissions.array as! [AppPermission]
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    private enum CodingKeys: String, CodingKey
    {
        case name
        case bundleIdentifier
        case developerName
        case localizedDescription
        case version
        case versionDescription
        case versionDate
        case iconURL
        case screenshotURLs
        case downloadURL
        case platformURLs
        case tintColor
        case subtitle
        case permissions
        case size
        case isBeta = "beta"
    }
    
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { preconditionFailure("Decoder must have non-nil NSManagedObjectContext.") }
        
        // Must initialize with context in order for child context saves to work correctly.
        super.init(entity: StoreApp.entity(), insertInto: context)
        
        do
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
            self.developerName = try container.decode(String.self, forKey: .developerName)
            self.localizedDescription = try container.decode(String.self, forKey: .localizedDescription)
            
            self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            
            self.version = try container.decode(String.self, forKey: .version)
            self.versionDate = try container.decode(Date.self, forKey: .versionDate)
            self.versionDescription = try container.decodeIfPresent(String.self, forKey: .versionDescription)
            
            self.iconURL = try container.decode(URL.self, forKey: .iconURL)
            self.screenshotURLs = try container.decodeIfPresent([URL].self, forKey: .screenshotURLs) ?? []
            
            let downloadURL = try container.decodeIfPresent(URL.self, forKey: .downloadURL)
            let platformURLs = try container.decodeIfPresent(PlatformURLs.self.self, forKey: .platformURLs)
            if let platformURLs = platformURLs {
                self.platformURLs = platformURLs
                // Backwards compatibility, use the fiirst (iOS will be first since sorted that way)
                if let first = platformURLs.sorted().first {
                    self.downloadURL = first.downloadURL
                } else {
                    throw DecodingError.dataCorruptedError(forKey: .platformURLs, in: container, debugDescription: "platformURLs has no entries")

                }
                    
            } else if let downloadURL = downloadURL {
                self.downloadURL = downloadURL
            } else {
                throw DecodingError.dataCorruptedError(forKey: .downloadURL, in: container, debugDescription: "E downloadURL:String or downloadURLs:[[Platform:URL]] key required.")
            }
            
            if let tintColorHex = try container.decodeIfPresent(String.self, forKey: .tintColor)
            {
                guard let tintColor = UIColor(hexString: tintColorHex) else {
                    throw DecodingError.dataCorruptedError(forKey: .tintColor, in: container, debugDescription: "Hex code is invalid.")
                }
                
                self.tintColor = tintColor
            }
            
            self.size = try container.decode(Int32.self, forKey: .size)
            self.isBeta = try container.decodeIfPresent(Bool.self, forKey: .isBeta) ?? false
            
            let permissions = try container.decodeIfPresent([AppPermission].self, forKey: .permissions) ?? []
            self._permissions = NSOrderedSet(array: permissions)
        }
        catch
        {
            if let context = self.managedObjectContext
            {
                context.delete(self)
            }
            
            throw error
        }
    }
}

public extension StoreApp
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<StoreApp>
    {
        return NSFetchRequest<StoreApp>(entityName: "StoreApp")
    }
    
    class func makeAltStoreApp(in context: NSManagedObjectContext) -> StoreApp
    {
        let app = StoreApp(context: context)
        app.name = "SideStore"
        app.bundleIdentifier = StoreApp.altstoreAppID
        app.developerName = "Side Team"
        app.localizedDescription = "SideStore is an alternative App Store."
        app.iconURL = URL(string: "https://user-images.githubusercontent.com/705880/63392210-540c5980-c37b-11e9-968c-8742fc68ab2e.png")!
        app.screenshotURLs = []
        app.version = "1.0"
        app.versionDate = Date()
        app.downloadURL = URL(string: "http://rileytestut.com")!
        
        #if BETA
        app.isBeta = true
        #endif
        
        return app
    }
}
