import Foundation
import KoardSDK

extension Location {
    static let downtownCoffee = Location(
        id: "loc_001",
        name: "Downtown Coffee",
        address: Address(
            streetLine1: "123 Main St",
            streetLine2: "Suite 200",
            city: "Austin",
            state: "TX",
            zip: "78701"
        ),
        accountId: "acct_123",
        phone: "512-555-1234",
        email: "contact@downtowncoffee.com",
        status: "active",
        processorConfigId: "proc_001",
        countryCode: "US",
        currency: "USD",
        terminalId: "term_001",
        metadata: ["type": "coffee", "hours": "7am-7pm"],
        createdAt: "2024-01-01T12:00:00Z",
        updatedAt: "2024-06-01T08:30:00Z",
        deletedAt: nil
    )

    static let theBookLoft = Location(
        id: "loc_002",
        name: "The Book Loft",
        address: Address(
            streetLine1: "456 Oak Ave",
            streetLine2: "",
            city: "Columbus",
            state: "OH",
            zip: "43215"
        ),
        accountId: "acct_456",
        phone: "614-555-4567",
        email: "info@bookloft.com",
        status: "inactive",
        processorConfigId: "proc_002",
        countryCode: "US",
        currency: "USD",
        terminalId: "term_002",
        metadata: ["type": "bookstore"],
        createdAt: "2023-10-15T09:45:00Z",
        updatedAt: "2024-02-20T17:10:00Z",
        deletedAt: nil
    )

    static let seasideGrill = Location(
        id: "loc_003",
        name: "Seaside Grill",
        address: Address(
            streetLine1: "789 Ocean Blvd",
            streetLine2: "Building B",
            city: "Santa Monica",
            state: "CA",
            zip: "90401"
        ),
        accountId: "acct_789",
        phone: nil,
        email: nil,
        status: "active",
        processorConfigId: nil,
        countryCode: "US",
        currency: "USD",
        terminalId: nil,
        metadata: ["type": "restaurant", "outdoorSeating": "yes"],
        createdAt: "2022-07-04T14:30:00Z",
        updatedAt: "2024-05-10T16:00:00Z",
        deletedAt: nil
    )
}
