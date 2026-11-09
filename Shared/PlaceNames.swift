//
//  PlaceNames.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Bangla names for KUET bus stops and places. Firestore keeps the English name
//  as the stop's identity (favourite stop, matching routes), and the app swaps in
//  the Bangla name only when it shows text to a person using the app in Bangla.
//
//  Where a name comes from:
//  1. The stop's or route's own nameBn, typed by the admin in the route editor.
//  2. Otherwise this built-in list of known Khulna places.
//  3. Otherwise the English name, unchanged.
//
//  Compiled into the app and the widget, so it must not use Firebase.
//

import Foundation

enum PlaceNames {
    // English name -> Bangla. Keys are compared lowercased.
    static let known: [String: String] = [
        "kuet": "কুয়েট",
        "kuet main gate": "কুয়েট মেইন গেট",
        "kuet mosque": "কুয়েট মসজিদ",
        "fulbarigate": "ফুলবাড়ীগেট",
        "daulatpur": "দৌলতপুর",
        "notun rasta": "নতুন রাস্তা",
        "sonadanga": "সোনাডাঙ্গা",
        "sonadanga bus terminal": "সোনাডাঙ্গা বাস টার্মিনাল",
        "shibbari": "শিববাড়ী",
        "shibbari more": "শিববাড়ী মোড়",
        "shibbari mor": "শিববাড়ী মোড়",
        "royal more": "রয়্যাল মোড়",
        "royal mor": "রয়্যাল মোড়",
        "boyra": "বয়রা",
        "boyra bazar": "বয়রা বাজার",
        "khalishpur": "খালিশপুর",
        "rupsha": "রূপসা",
        "gollamari": "গল্লামারী",
        "moylapota": "ময়লাপোতা",
        "dakbangla": "ডাকবাংলা",
        "fultala bazar": "ফুলতলা বাজার",
        "ferighat": "ফেরিঘাট",
        "nirala": "নিরালা",
        "powerhouse mor": "পাওয়ার হাউস মোড়",
        "college mor": "কলেজ মোড়",
        "joragate": "জোড়াগেট",
        "alamnagar": "আলমনগর",
        "platinum mor": "প্লাটিনাম মোড়",
        "goalkhali": "গোয়ালখালী",
        "shiromoni": "শিরোমণি",
        "shiromoni bazar": "শিরোমণি বাজার",
        "afil gate": "আফিল গেট",
        "afilgate": "আফিল গেট",
        "pother bazar": "পথের বাজার",
        "khulna": "খুলনা"
    ]

    // True when the app is showing Bangla (the phone's language, or this app's own setting).
    static var isBangla: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("bn") ?? false
    }

    // The name to show. `bangla` is the admin's own Bangla name, if one was typed.
    static func display(_ english: String, bangla: String? = nil) -> String {
        display(english, bangla: bangla, inBangla: isBangla)
    }

    // Same, with the language passed in, so it can be unit tested.
    static func display(_ english: String, bangla: String?, inBangla: Bool) -> String {
        guard inBangla else { return english }
        if let bangla = bangla?.trimmingCharacters(in: .whitespaces), !bangla.isEmpty {
            return bangla
        }
        return translate(english)
    }

    // "KUET to Sonadanga" or "Normal-2 · Rupsha": translates each known place
    // and keeps everything else (such as "Normal-2") as it is.
    static func translate(_ english: String) -> String {
        if let whole = known[english.lowercased().trimmingCharacters(in: .whitespaces)] {
            return whole
        }
        for separator in [" · ", " to ", " - "] where english.contains(separator) {
            let parts = english.components(separatedBy: separator).map(translate)
            let joiner = separator == " to " ? " – " : separator
            return parts.joined(separator: joiner)
        }
        return english
    }
}
