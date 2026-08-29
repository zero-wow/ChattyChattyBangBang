local addon = ChattyChattyBangBang

-- Server knowledge lives here on purpose.  The portable core only asks an
-- active provider whether it wants to annotate an already-normalized record.
local Ascension = {
	id = "ascension",
	label = "Ascension",
	classifiers = {},
}

function Ascension:RegisterClassifier(callback)
	if type(callback) == "function" then
		table.insert(self.classifiers, callback)
	end
end

function Ascension:ClassifyMessage(record)
	for index = 1, #self.classifiers do
		self.classifiers[index](record)
	end
end

addon.Compatibility:RegisterProvider("ascension", Ascension)
