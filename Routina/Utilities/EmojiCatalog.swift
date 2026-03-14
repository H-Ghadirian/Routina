import Foundation

enum EmojiCatalog {
    struct Option: Hashable, Identifiable {
        let emoji: String
        fileprivate let searchTokens: [String]
        fileprivate let name: String

        var id: String { emoji }
        var accessibilityLabel: String { name }
    }

    static let quick: [String] = ["✨", "✅", "📞", "🏃‍♂️", "💊", "🧘", "📚", "🧴", "🧹", "🛒", "💧", "😴"]

    static let all: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥹", "☺️", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍",
        "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳",
        "🙂‍↕️", "🙂‍↔️", "😏", "😒", "🙂‍↔️", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺",
        "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😶‍🌫️", "😱", "😨", "😰", "😥", "😓",
        "🤗", "🤔", "🫣", "🤭", "🫢", "🫡", "🤫", "🫠", "🤥", "😶", "🫥", "😐", "🫤", "😑", "😬", "🙄", "😯",
        "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😮‍💨", "😵", "😵‍💫", "🤐", "🥴", "🤢", "🤮", "🤧",
        "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿", "👻", "💀", "☠️", "🤖",

        "👋", "🤚", "🖐️", "✋", "🖖", "🫱", "🫲", "🫳", "🫴", "👌", "🤌", "🤏", "✌️", "🤞", "🫰", "🤟",
        "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "🫵", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌",
        "🫶", "👐", "🤲", "🤝", "🙏", "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠",
        "🫀", "🫁", "🦷", "🦴", "👀", "👁️", "👅", "👄",

        "👶", "🧒", "👦", "👧", "🧑", "👱", "👨", "🧔", "👩", "🧓", "👴", "👵", "🙍", "🙎", "🙅", "🙆", "💁",
        "🙋", "🧏", "🙇", "🤦", "🤷", "🧘", "🏃", "🚶", "🧍", "🧎", "🧑‍💻", "🧑‍🏫", "🧑‍⚕️", "🧑‍🍳", "🧑‍🔧", "🧑‍🎨",

        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈",
        "🙉", "🙊", "🐔", "🐧", "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🪲", "🐛",
        "🦋", "🐌", "🐞", "🐜", "🪰", "🪱", "🐢", "🐍", "🦎", "🦂", "🦀", "🐙", "🦑", "🦐", "🐠", "🐟", "🐡",
        "🦈", "🐬", "🐳", "🐋",

        "🌵", "🎄", "🌲", "🌳", "🌴", "🪴", "🌱", "🌿", "☘️", "🍀", "🎍", "🪵", "🍂", "🍁", "🍄", "🐚", "🌾",
        "💐", "🌷", "🪷", "🌹", "🥀", "🌺", "🌸", "🌼", "🌻", "🌞", "🌝", "🌛", "🌜", "🌚", "🌕", "🌖", "🌗",
        "🌘", "🌑", "🌒", "🌓", "🌔", "🌙", "🌎", "🌍", "🌏", "🪐", "⭐️", "🌟", "✨", "⚡️", "☄️", "💥", "🔥",
        "🌈", "☀️", "🌤️", "⛅️", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️", "⛄️", "🌬️", "💨",
        "💧", "💦", "☔️",

        "🍏", "🍎", "🍐", "🍊", "🍋", "🍋‍🟩", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥",
        "🥝", "🍅", "🫒", "🥑", "🍆", "🥔", "🥕", "🌽", "🌶️", "🫑", "🥒", "🥬", "🥦", "🧄", "🧅", "🍄", "🥜",
        "🫘", "🌰", "🍞", "🥐", "🥖", "🫓", "🥨", "🥯", "🥞", "🧇", "🧀", "🍖", "🍗", "🥩", "🥓", "🍔", "🍟",
        "🍕", "🌭", "🥪", "🌮", "🌯", "🫔", "🥙", "🧆", "🥚", "🍳", "🥘", "🍲", "🫕", "🥣", "🥗", "🍿", "🧈",
        "🧂", "🥫", "🍱", "🍘", "🍙", "🍚", "🍛", "🍜", "🍝", "🍠", "🍢", "🍣", "🍤", "🍥", "🥮", "🍡", "🥟",
        "🥠", "🥡", "🍦", "🍧", "🍨", "🍩", "🍪", "🎂", "🍰", "🧁", "🥧", "🍫", "🍬", "🍭", "🍮", "🍯", "🍼",
        "🥛", "☕️", "🫖", "🍵", "🧃", "🥤", "🧋", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🧉",

        "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏",
        "🪃", "🥅", "⛳️", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️",
        "🏂", "🏋️", "🤸", "⛹️", "🤺", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🚴", "🚵", "🏎️", "🏍️",
        "🤹", "🕺", "💃",

        "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🛻", "🚚", "🚛", "🚜", "🛴", "🚲", "🛵",
        "🏍️", "✈️", "🛫", "🛬", "🚀", "🛸", "🚁", "⛵️", "🚤", "🛶", "🛥️", "🚢", "⚓️", "🚧", "🗺️", "🧭",

        "⌚️", "📱", "📲", "💻", "⌨️", "🖥️", "🖨️", "🖱️", "🧮", "💽", "💾", "📷", "📸", "📹", "🎥", "📞", "☎️",
        "📟", "📠", "📺", "📻", "🎙️", "🎚️", "🎛️", "🧭", "⏰", "⏱️", "⏲️", "🕰️", "⌛️", "⏳", "📡", "🔋", "🔌",
        "💡", "🔦", "🕯️", "🪔", "🧯", "🛢️", "💸", "💵", "💴", "💶", "💷", "🪙", "💳", "🪪", "🧾", "📦",

        "🧹", "🧺", "🧽", "🪣", "🧴", "🪥", "🪒", "🧼", "🛁", "🚿", "🚽", "🛏️", "🛋️", "🪑", "🚪", "🪞", "🪟",
        "🧸", "🪆", "🎁", "🎈", "🎉", "🎊", "🛒", "🧳", "🗝️", "🔑", "🏠", "🏡", "🏢", "🏥", "🏫", "🏬", "🏦",

        "❤️", "🩷", "🧡", "💛", "💚", "🩵", "💙", "💜", "🤎", "🖤", "🩶", "🤍", "💔", "❤️‍🔥", "❤️‍🩹", "❣️",
        "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️",
        "☦️", "🛐", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "🆔", "⚠️",
        "🚫", "✅", "☑️", "❌", "⭕️", "➕", "➖", "➗", "✖️", "♻️"
    ]

    static let uniqueQuick = makeUnique(quick)
    static let uniqueAll = makeUnique(all)
    static let searchableAll = makeUnique(quick + all).map(makeOption)

    static func filter(_ options: [Option], matching query: String) -> [Option] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return options }

        let normalizedQueryTokens = normalizedSearchTokens(trimmedQuery)

        return options.filter { option in
            option.emoji == trimmedQuery
                || (!normalizedQueryTokens.isEmpty && matches(normalizedQueryTokens, in: option.searchTokens))
        }
    }

    private static let ignoredScalarNames: Set<String> = [
        "ZERO WIDTH JOINER",
        "VARIATION SELECTOR-16"
    ]

    private static let searchAliases: [String: [String]] = [
        "✨": ["sparkles", "favorite", "default"],
        "✅": ["check", "done", "complete", "completed", "task"],
        "📞": ["call", "phone", "ring"],
        "🏃": ["run", "running", "exercise", "workout", "jog"],
        "🏃‍♂️": ["run", "running", "exercise", "workout", "jog"],
        "💊": ["pill", "medicine", "medication", "vitamin", "supplement"],
        "🧘": ["meditate", "meditation", "yoga", "mindfulness", "calm"],
        "📚": ["read", "reading", "book", "study", "learn"],
        "🧴": ["lotion", "moisturizer", "skincare", "skin", "sunscreen"],
        "🧹": ["clean", "cleaning", "chore", "chores", "sweep", "tidy"],
        "🛒": ["shop", "shopping", "grocery", "groceries", "store", "buy"],
        "💧": ["water", "drink", "hydrate", "hydration"],
        "😴": ["sleep", "bed", "rest", "nap"],
        "🚶": ["walk", "walking", "steps", "stroll"],
        "🏋️": ["lift", "lifting", "gym", "exercise", "workout"],
        "🤸": ["stretch", "stretching", "mobility", "exercise"],
        "🧼": ["soap", "wash", "washing", "clean"],
        "🛏️": ["bed", "sleep", "rest"],
        "📱": ["phone", "mobile"],
        "☕️": ["coffee", "drink", "cafe"]
    ]

    private static func makeUnique(_ source: [String]) -> [String] {
        var seen = Set<String>()
        return source.filter { seen.insert($0).inserted }
    }

    private static func makeOption(_ emoji: String) -> Option {
        let scalarNames = emoji.unicodeScalars.compactMap { scalar -> String? in
            guard let name = scalar.properties.name, !ignoredScalarNames.contains(name) else {
                return nil
            }
            return name.replacingOccurrences(of: "-", with: " ")
        }
        let aliases = searchAliases[emoji, default: []]
        let readableName = scalarNames.joined(separator: " ").lowercased()

        return Option(
            emoji: emoji,
            searchTokens: makeUnique((scalarNames + aliases).flatMap(normalizedSearchTokens)),
            name: readableName.isEmpty ? "emoji" : readableName
        )
    }

    private static func normalizedSearchTokens(_ value: String) -> [String] {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func matches(_ queryTokens: [String], in optionTokens: [String]) -> Bool {
        queryTokens.allSatisfy { queryToken in
            optionTokens.contains { $0.hasPrefix(queryToken) }
        }
    }
}
