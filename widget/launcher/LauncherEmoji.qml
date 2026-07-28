import QtQuick
import Quickshell

Item {
    id: root

    readonly property var entries: [
        {
            "glyph": "😀",
            "name": "Grinning face",
            "keywords": "grinning smile happy"
        },
        {
            "glyph": "😃",
            "name": "Grinning face with big eyes",
            "keywords": "smiley happy joy haha"
        },
        {
            "glyph": "😄",
            "name": "Grinning face with smiling eyes",
            "keywords": "smile happy joy laugh pleased"
        },
        {
            "glyph": "😁",
            "name": "Beaming face with smiling eyes",
            "keywords": "grin"
        },
        {
            "glyph": "😆",
            "name": "Grinning squinting face",
            "keywords": "laughing satisfied happy haha"
        },
        {
            "glyph": "😅",
            "name": "Grinning face with sweat",
            "keywords": "sweat_smile hot"
        },
        {
            "glyph": "🤣",
            "name": "Rolling on the floor laughing",
            "keywords": "rofl lol laughing"
        },
        {
            "glyph": "😂",
            "name": "Face with tears of joy",
            "keywords": "joy tears"
        },
        {
            "glyph": "🙂",
            "name": "Slightly smiling face",
            "keywords": "slightly_smiling_face"
        },
        {
            "glyph": "🙃",
            "name": "Upside-down face",
            "keywords": "upside_down_face"
        },
        {
            "glyph": "🫠",
            "name": "Melting face",
            "keywords": "melting_face sarcasm dread"
        },
        {
            "glyph": "😉",
            "name": "Winking face",
            "keywords": "wink flirt"
        },
        {
            "glyph": "😊",
            "name": "Smiling face with smiling eyes",
            "keywords": "blush proud"
        },
        {
            "glyph": "😇",
            "name": "Smiling face with halo",
            "keywords": "innocent angel"
        },
        {
            "glyph": "🥰",
            "name": "Smiling face with hearts",
            "keywords": "smiling_face_with_three_hearts love"
        },
        {
            "glyph": "😍",
            "name": "Smiling face with heart-eyes",
            "keywords": "heart_eyes love crush"
        },
        {
            "glyph": "🤩",
            "name": "Star-struck",
            "keywords": "star_struck eyes"
        },
        {
            "glyph": "😘",
            "name": "Face blowing a kiss",
            "keywords": "kissing_heart flirt"
        },
        {
            "glyph": "😗",
            "name": "Kissing face",
            "keywords": "kissing"
        },
        {
            "glyph": "☺️",
            "name": "Smiling face",
            "keywords": "relaxed blush pleased"
        },
        {
            "glyph": "😚",
            "name": "Kissing face with closed eyes",
            "keywords": "kissing_closed_eyes"
        },
        {
            "glyph": "😙",
            "name": "Kissing face with smiling eyes",
            "keywords": "kissing_smiling_eyes"
        },
        {
            "glyph": "🥲",
            "name": "Smiling face with tear",
            "keywords": "smiling_face_with_tear"
        },
        {
            "glyph": "😋",
            "name": "Face savoring food",
            "keywords": "yum tongue lick"
        },
        {
            "glyph": "😛",
            "name": "Face with tongue",
            "keywords": "stuck_out_tongue"
        },
        {
            "glyph": "😜",
            "name": "Winking face with tongue",
            "keywords": "stuck_out_tongue_winking_eye prank silly"
        },
        {
            "glyph": "🤪",
            "name": "Zany face",
            "keywords": "zany_face goofy wacky"
        },
        {
            "glyph": "😝",
            "name": "Squinting face with tongue",
            "keywords": "stuck_out_tongue_closed_eyes prank"
        },
        {
            "glyph": "🤑",
            "name": "Money-mouth face",
            "keywords": "money_mouth_face rich"
        },
        {
            "glyph": "🤗",
            "name": "Smiling face with open hands",
            "keywords": "hugs"
        },
        {
            "glyph": "🤭",
            "name": "Face with hand over mouth",
            "keywords": "hand_over_mouth quiet whoops"
        },
        {
            "glyph": "🫢",
            "name": "Face with open eyes and hand over mouth",
            "keywords": "face_with_open_eyes_and_hand_over_mouth gasp shock"
        },
        {
            "glyph": "🫣",
            "name": "Face with peeking eye",
            "keywords": "face_with_peeking_eye"
        },
        {
            "glyph": "🤫",
            "name": "Shushing face",
            "keywords": "shushing_face silence quiet"
        },
        {
            "glyph": "🤔",
            "name": "Thinking face",
            "keywords": "thinking"
        },
        {
            "glyph": "🫡",
            "name": "Saluting face",
            "keywords": "saluting_face respect"
        },
        {
            "glyph": "🤐",
            "name": "Zipper-mouth face",
            "keywords": "zipper_mouth_face silence hush"
        },
        {
            "glyph": "🤨",
            "name": "Face with raised eyebrow",
            "keywords": "raised_eyebrow suspicious"
        },
        {
            "glyph": "😐",
            "name": "Neutral face",
            "keywords": "neutral_face meh"
        },
        {
            "glyph": "😑",
            "name": "Expressionless face",
            "keywords": "expressionless"
        },
        {
            "glyph": "😶",
            "name": "Face without mouth",
            "keywords": "no_mouth mute silence"
        },
        {
            "glyph": "🫥",
            "name": "Dotted line face",
            "keywords": "dotted_line_face invisible"
        },
        {
            "glyph": "😶‍🌫️",
            "name": "Face in clouds",
            "keywords": "face_in_clouds"
        },
        {
            "glyph": "😏",
            "name": "Smirking face",
            "keywords": "smirk smug"
        },
        {
            "glyph": "😒",
            "name": "Unamused face",
            "keywords": "unamused meh"
        },
        {
            "glyph": "🙄",
            "name": "Face with rolling eyes",
            "keywords": "roll_eyes"
        },
        {
            "glyph": "😬",
            "name": "Grimacing face",
            "keywords": "grimacing"
        },
        {
            "glyph": "😮‍💨",
            "name": "Face exhaling",
            "keywords": "face_exhaling"
        },
        {
            "glyph": "🤥",
            "name": "Lying face",
            "keywords": "lying_face liar"
        },
        {
            "glyph": "🫨",
            "name": "Shaking face",
            "keywords": "shaking_face shock"
        },
        {
            "glyph": "😌",
            "name": "Relieved face",
            "keywords": "relieved whew"
        },
        {
            "glyph": "😔",
            "name": "Pensive face",
            "keywords": "pensive"
        },
        {
            "glyph": "😪",
            "name": "Sleepy face",
            "keywords": "sleepy tired"
        },
        {
            "glyph": "🤤",
            "name": "Drooling face",
            "keywords": "drooling_face"
        },
        {
            "glyph": "😴",
            "name": "Sleeping face",
            "keywords": "sleeping zzz"
        },
        {
            "glyph": "😷",
            "name": "Face with medical mask",
            "keywords": "mask sick ill"
        },
        {
            "glyph": "🤒",
            "name": "Face with thermometer",
            "keywords": "face_with_thermometer sick"
        },
        {
            "glyph": "🤕",
            "name": "Face with head-bandage",
            "keywords": "face_with_head_bandage hurt"
        },
        {
            "glyph": "🤢",
            "name": "Nauseated face",
            "keywords": "nauseated_face sick barf disgusted"
        },
        {
            "glyph": "🤮",
            "name": "Face vomiting",
            "keywords": "vomiting_face barf sick"
        },
        {
            "glyph": "🤧",
            "name": "Sneezing face",
            "keywords": "sneezing_face achoo sick"
        },
        {
            "glyph": "🥵",
            "name": "Hot face",
            "keywords": "hot_face heat sweating"
        },
        {
            "glyph": "🥶",
            "name": "Cold face",
            "keywords": "cold_face freezing ice"
        },
        {
            "glyph": "🥴",
            "name": "Woozy face",
            "keywords": "woozy_face groggy"
        },
        {
            "glyph": "😵",
            "name": "Face with crossed-out eyes",
            "keywords": "dizzy_face"
        },
        {
            "glyph": "😵‍💫",
            "name": "Face with spiral eyes",
            "keywords": "face_with_spiral_eyes"
        },
        {
            "glyph": "🤯",
            "name": "Exploding head",
            "keywords": "exploding_head mind blown"
        },
        {
            "glyph": "🤠",
            "name": "Cowboy hat face",
            "keywords": "cowboy_hat_face"
        },
        {
            "glyph": "🥳",
            "name": "Partying face",
            "keywords": "partying_face celebration birthday"
        },
        {
            "glyph": "🥸",
            "name": "Disguised face",
            "keywords": "disguised_face"
        },
        {
            "glyph": "😎",
            "name": "Smiling face with sunglasses",
            "keywords": "sunglasses cool"
        },
        {
            "glyph": "🤓",
            "name": "Nerd face",
            "keywords": "nerd_face geek glasses"
        },
        {
            "glyph": "🧐",
            "name": "Face with monocle",
            "keywords": "monocle_face"
        },
        {
            "glyph": "😕",
            "name": "Confused face",
            "keywords": "confused"
        },
        {
            "glyph": "🫤",
            "name": "Face with diagonal mouth",
            "keywords": "face_with_diagonal_mouth confused"
        },
        {
            "glyph": "😟",
            "name": "Worried face",
            "keywords": "worried nervous"
        },
        {
            "glyph": "🙁",
            "name": "Slightly frowning face",
            "keywords": "slightly_frowning_face"
        },
        {
            "glyph": "☹️",
            "name": "Frowning face",
            "keywords": "frowning_face"
        },
        {
            "glyph": "😮",
            "name": "Face with open mouth",
            "keywords": "open_mouth surprise impressed wow"
        },
        {
            "glyph": "😯",
            "name": "Hushed face",
            "keywords": "hushed silence speechless"
        },
        {
            "glyph": "😲",
            "name": "Astonished face",
            "keywords": "astonished amazed gasp"
        },
        {
            "glyph": "😳",
            "name": "Flushed face",
            "keywords": "flushed"
        },
        {
            "glyph": "🥺",
            "name": "Pleading face",
            "keywords": "pleading_face puppy eyes"
        },
        {
            "glyph": "🥹",
            "name": "Face holding back tears",
            "keywords": "face_holding_back_tears tears gratitude"
        },
        {
            "glyph": "😦",
            "name": "Frowning face with open mouth",
            "keywords": "frowning"
        },
        {
            "glyph": "😧",
            "name": "Anguished face",
            "keywords": "anguished stunned"
        },
        {
            "glyph": "😨",
            "name": "Fearful face",
            "keywords": "fearful scared shocked oops"
        },
        {
            "glyph": "😰",
            "name": "Anxious face with sweat",
            "keywords": "cold_sweat nervous"
        },
        {
            "glyph": "😥",
            "name": "Sad but relieved face",
            "keywords": "disappointed_relieved phew sweat nervous"
        },
        {
            "glyph": "😢",
            "name": "Crying face",
            "keywords": "cry sad tear"
        },
        {
            "glyph": "😭",
            "name": "Loudly crying face",
            "keywords": "sob sad cry bawling"
        },
        {
            "glyph": "😱",
            "name": "Face screaming in fear",
            "keywords": "scream horror shocked"
        },
        {
            "glyph": "😖",
            "name": "Confounded face",
            "keywords": "confounded"
        },
        {
            "glyph": "😣",
            "name": "Persevering face",
            "keywords": "persevere struggling"
        },
        {
            "glyph": "😞",
            "name": "Disappointed face",
            "keywords": "disappointed sad"
        },
        {
            "glyph": "😓",
            "name": "Downcast face with sweat",
            "keywords": "sweat"
        },
        {
            "glyph": "😩",
            "name": "Weary face",
            "keywords": "weary tired"
        },
        {
            "glyph": "😫",
            "name": "Tired face",
            "keywords": "tired_face upset whine"
        },
        {
            "glyph": "🥱",
            "name": "Yawning face",
            "keywords": "yawning_face"
        },
        {
            "glyph": "😤",
            "name": "Face with steam from nose",
            "keywords": "triumph smug"
        },
        {
            "glyph": "😡",
            "name": "Enraged face",
            "keywords": "rage pout angry"
        },
        {
            "glyph": "😠",
            "name": "Angry face",
            "keywords": "angry mad annoyed"
        },
        {
            "glyph": "🤬",
            "name": "Face with symbols on mouth",
            "keywords": "cursing_face foul"
        },
        {
            "glyph": "😈",
            "name": "Smiling face with horns",
            "keywords": "smiling_imp devil evil horns"
        },
        {
            "glyph": "👿",
            "name": "Angry face with horns",
            "keywords": "imp angry devil evil horns"
        },
        {
            "glyph": "💀",
            "name": "Skull",
            "keywords": "skull dead danger poison"
        },
        {
            "glyph": "☠️",
            "name": "Skull and crossbones",
            "keywords": "skull_and_crossbones danger pirate"
        },
        {
            "glyph": "💩",
            "name": "Pile of poo",
            "keywords": "hankey poop shit crap"
        },
        {
            "glyph": "🤡",
            "name": "Clown face",
            "keywords": "clown_face"
        },
        {
            "glyph": "👹",
            "name": "Ogre",
            "keywords": "japanese_ogre monster"
        },
        {
            "glyph": "👺",
            "name": "Goblin",
            "keywords": "japanese_goblin"
        },
        {
            "glyph": "👻",
            "name": "Ghost",
            "keywords": "ghost halloween"
        },
        {
            "glyph": "👽",
            "name": "Alien",
            "keywords": "alien ufo"
        },
        {
            "glyph": "👾",
            "name": "Alien monster",
            "keywords": "space_invader game retro"
        },
        {
            "glyph": "🤖",
            "name": "Robot",
            "keywords": "robot"
        },
        {
            "glyph": "😺",
            "name": "Grinning cat",
            "keywords": "smiley_cat"
        },
        {
            "glyph": "😸",
            "name": "Grinning cat with smiling eyes",
            "keywords": "smile_cat"
        },
        {
            "glyph": "😹",
            "name": "Cat with tears of joy",
            "keywords": "joy_cat"
        },
        {
            "glyph": "😻",
            "name": "Smiling cat with heart-eyes",
            "keywords": "heart_eyes_cat"
        },
        {
            "glyph": "😼",
            "name": "Cat with wry smile",
            "keywords": "smirk_cat"
        },
        {
            "glyph": "😽",
            "name": "Kissing cat",
            "keywords": "kissing_cat"
        },
        {
            "glyph": "🙀",
            "name": "Weary cat",
            "keywords": "scream_cat horror"
        },
        {
            "glyph": "😿",
            "name": "Crying cat",
            "keywords": "crying_cat_face sad tear"
        },
        {
            "glyph": "😾",
            "name": "Pouting cat",
            "keywords": "pouting_cat"
        },
        {
            "glyph": "🙈",
            "name": "See-no-evil monkey",
            "keywords": "see_no_evil monkey blind ignore"
        },
        {
            "glyph": "🙉",
            "name": "Hear-no-evil monkey",
            "keywords": "hear_no_evil monkey deaf"
        },
        {
            "glyph": "🙊",
            "name": "Speak-no-evil monkey",
            "keywords": "speak_no_evil monkey mute hush"
        },
        {
            "glyph": "💌",
            "name": "Love letter",
            "keywords": "love_letter email envelope"
        },
        {
            "glyph": "💘",
            "name": "Heart with arrow",
            "keywords": "cupid love heart"
        },
        {
            "glyph": "💝",
            "name": "Heart with ribbon",
            "keywords": "gift_heart chocolates"
        },
        {
            "glyph": "💖",
            "name": "Sparkling heart",
            "keywords": "sparkling_heart"
        },
        {
            "glyph": "💗",
            "name": "Growing heart",
            "keywords": "heartpulse"
        },
        {
            "glyph": "💓",
            "name": "Beating heart",
            "keywords": "heartbeat"
        },
        {
            "glyph": "💞",
            "name": "Revolving hearts",
            "keywords": "revolving_hearts"
        },
        {
            "glyph": "💕",
            "name": "Two hearts",
            "keywords": "two_hearts"
        },
        {
            "glyph": "💟",
            "name": "Heart decoration",
            "keywords": "heart_decoration"
        },
        {
            "glyph": "❣️",
            "name": "Heart exclamation",
            "keywords": "heavy_heart_exclamation"
        },
        {
            "glyph": "💔",
            "name": "Broken heart",
            "keywords": "broken_heart"
        },
        {
            "glyph": "❤️‍🔥",
            "name": "Heart on fire",
            "keywords": "heart_on_fire"
        },
        {
            "glyph": "❤️‍🩹",
            "name": "Mending heart",
            "keywords": "mending_heart"
        },
        {
            "glyph": "❤️",
            "name": "Red heart",
            "keywords": "heart love"
        },
        {
            "glyph": "🩷",
            "name": "Pink heart",
            "keywords": "pink_heart"
        },
        {
            "glyph": "🧡",
            "name": "Orange heart",
            "keywords": "orange_heart"
        },
        {
            "glyph": "💛",
            "name": "Yellow heart",
            "keywords": "yellow_heart"
        },
        {
            "glyph": "💚",
            "name": "Green heart",
            "keywords": "green_heart"
        },
        {
            "glyph": "💙",
            "name": "Blue heart",
            "keywords": "blue_heart"
        },
        {
            "glyph": "🩵",
            "name": "Light blue heart",
            "keywords": "light_blue_heart"
        },
        {
            "glyph": "💜",
            "name": "Purple heart",
            "keywords": "purple_heart"
        },
        {
            "glyph": "🤎",
            "name": "Brown heart",
            "keywords": "brown_heart"
        },
        {
            "glyph": "🖤",
            "name": "Black heart",
            "keywords": "black_heart"
        },
        {
            "glyph": "🩶",
            "name": "Grey heart",
            "keywords": "grey_heart"
        },
        {
            "glyph": "🤍",
            "name": "White heart",
            "keywords": "white_heart"
        },
        {
            "glyph": "💋",
            "name": "Kiss mark",
            "keywords": "kiss lipstick"
        },
        {
            "glyph": "💯",
            "name": "Hundred points",
            "keywords": "100 score perfect"
        },
        {
            "glyph": "💢",
            "name": "Anger symbol",
            "keywords": "anger angry"
        },
        {
            "glyph": "💥",
            "name": "Collision",
            "keywords": "boom collision explode"
        },
        {
            "glyph": "💫",
            "name": "Dizzy",
            "keywords": "dizzy star"
        },
        {
            "glyph": "💦",
            "name": "Sweat droplets",
            "keywords": "sweat_drops water workout"
        },
        {
            "glyph": "💨",
            "name": "Dashing away",
            "keywords": "dash wind blow fast"
        },
        {
            "glyph": "🕳️",
            "name": "Hole",
            "keywords": "hole"
        },
        {
            "glyph": "💬",
            "name": "Speech balloon",
            "keywords": "speech_balloon comment"
        },
        {
            "glyph": "👁️‍🗨️",
            "name": "Eye in speech bubble",
            "keywords": "eye_speech_bubble"
        },
        {
            "glyph": "🗨️",
            "name": "Left speech bubble",
            "keywords": "left_speech_bubble"
        },
        {
            "glyph": "🗯️",
            "name": "Right anger bubble",
            "keywords": "right_anger_bubble"
        },
        {
            "glyph": "💭",
            "name": "Thought balloon",
            "keywords": "thought_balloon thinking"
        },
        {
            "glyph": "💤",
            "name": "Zzz",
            "keywords": "zzz sleeping"
        },
        {
            "glyph": "👋",
            "name": "Waving hand",
            "keywords": "wave goodbye"
        },
        {
            "glyph": "🤚",
            "name": "Raised back of hand",
            "keywords": "raised_back_of_hand"
        },
        {
            "glyph": "🖐️",
            "name": "Hand with fingers splayed",
            "keywords": "raised_hand_with_fingers_splayed"
        },
        {
            "glyph": "✋",
            "name": "Raised hand",
            "keywords": "hand raised_hand highfive stop"
        },
        {
            "glyph": "🖖",
            "name": "Vulcan salute",
            "keywords": "vulcan_salute prosper spock"
        },
        {
            "glyph": "🫱",
            "name": "Rightwards hand",
            "keywords": "rightwards_hand"
        },
        {
            "glyph": "🫲",
            "name": "Leftwards hand",
            "keywords": "leftwards_hand"
        },
        {
            "glyph": "🫳",
            "name": "Palm down hand",
            "keywords": "palm_down_hand"
        },
        {
            "glyph": "🫴",
            "name": "Palm up hand",
            "keywords": "palm_up_hand"
        },
        {
            "glyph": "🫷",
            "name": "Leftwards pushing hand",
            "keywords": "leftwards_pushing_hand"
        },
        {
            "glyph": "🫸",
            "name": "Rightwards pushing hand",
            "keywords": "rightwards_pushing_hand"
        },
        {
            "glyph": "👌",
            "name": "Ok hand",
            "keywords": "ok_hand"
        },
        {
            "glyph": "🤌",
            "name": "Pinched fingers",
            "keywords": "pinched_fingers"
        },
        {
            "glyph": "🤏",
            "name": "Pinching hand",
            "keywords": "pinching_hand"
        },
        {
            "glyph": "✌️",
            "name": "Victory hand",
            "keywords": "v victory peace"
        },
        {
            "glyph": "🤞",
            "name": "Crossed fingers",
            "keywords": "crossed_fingers luck hopeful"
        },
        {
            "glyph": "🫰",
            "name": "Hand with index finger and thumb crossed",
            "keywords": "hand_with_index_finger_and_thumb_crossed"
        },
        {
            "glyph": "🤟",
            "name": "Love-you gesture",
            "keywords": "love_you_gesture"
        },
        {
            "glyph": "🤘",
            "name": "Sign of the horns",
            "keywords": "metal"
        },
        {
            "glyph": "🤙",
            "name": "Call me hand",
            "keywords": "call_me_hand"
        },
        {
            "glyph": "👈",
            "name": "Backhand index pointing left",
            "keywords": "point_left"
        },
        {
            "glyph": "👉",
            "name": "Backhand index pointing right",
            "keywords": "point_right"
        },
        {
            "glyph": "👆",
            "name": "Backhand index pointing up",
            "keywords": "point_up_2"
        },
        {
            "glyph": "🖕",
            "name": "Middle finger",
            "keywords": "middle_finger fu"
        },
        {
            "glyph": "👇",
            "name": "Backhand index pointing down",
            "keywords": "point_down"
        },
        {
            "glyph": "☝️",
            "name": "Index pointing up",
            "keywords": "point_up"
        },
        {
            "glyph": "🫵",
            "name": "Index pointing at the viewer",
            "keywords": "index_pointing_at_the_viewer"
        },
        {
            "glyph": "👍",
            "name": "Thumbs up",
            "keywords": "+1 thumbsup approve ok"
        },
        {
            "glyph": "👎",
            "name": "Thumbs down",
            "keywords": "-1 thumbsdown disapprove bury"
        },
        {
            "glyph": "✊",
            "name": "Raised fist",
            "keywords": "fist_raised fist power"
        },
        {
            "glyph": "👊",
            "name": "Oncoming fist",
            "keywords": "fist_oncoming facepunch punch attack"
        },
        {
            "glyph": "🤛",
            "name": "Left-facing fist",
            "keywords": "fist_left"
        },
        {
            "glyph": "🤜",
            "name": "Right-facing fist",
            "keywords": "fist_right"
        },
        {
            "glyph": "👏",
            "name": "Clapping hands",
            "keywords": "clap praise applause"
        },
        {
            "glyph": "🙌",
            "name": "Raising hands",
            "keywords": "raised_hands hooray"
        },
        {
            "glyph": "🫶",
            "name": "Heart hands",
            "keywords": "heart_hands love"
        },
        {
            "glyph": "👐",
            "name": "Open hands",
            "keywords": "open_hands"
        },
        {
            "glyph": "🤲",
            "name": "Palms up together",
            "keywords": "palms_up_together"
        },
        {
            "glyph": "🤝",
            "name": "Handshake",
            "keywords": "handshake deal"
        },
        {
            "glyph": "🙏",
            "name": "Folded hands",
            "keywords": "pray please hope wish"
        },
        {
            "glyph": "✍️",
            "name": "Writing hand",
            "keywords": "writing_hand"
        },
        {
            "glyph": "💅",
            "name": "Nail polish",
            "keywords": "nail_care beauty manicure"
        },
        {
            "glyph": "🤳",
            "name": "Selfie",
            "keywords": "selfie"
        },
        {
            "glyph": "💪",
            "name": "Flexed biceps",
            "keywords": "muscle flex bicep strong workout"
        },
        {
            "glyph": "🦾",
            "name": "Mechanical arm",
            "keywords": "mechanical_arm"
        },
        {
            "glyph": "🦿",
            "name": "Mechanical leg",
            "keywords": "mechanical_leg"
        },
        {
            "glyph": "🦵",
            "name": "Leg",
            "keywords": "leg"
        },
        {
            "glyph": "🦶",
            "name": "Foot",
            "keywords": "foot"
        },
        {
            "glyph": "👂",
            "name": "Ear",
            "keywords": "ear hear sound listen"
        },
        {
            "glyph": "🦻",
            "name": "Ear with hearing aid",
            "keywords": "ear_with_hearing_aid"
        },
        {
            "glyph": "👃",
            "name": "Nose",
            "keywords": "nose smell"
        },
        {
            "glyph": "🧠",
            "name": "Brain",
            "keywords": "brain"
        },
        {
            "glyph": "🫀",
            "name": "Anatomical heart",
            "keywords": "anatomical_heart"
        },
        {
            "glyph": "🫁",
            "name": "Lungs",
            "keywords": "lungs"
        },
        {
            "glyph": "🦷",
            "name": "Tooth",
            "keywords": "tooth"
        },
        {
            "glyph": "🦴",
            "name": "Bone",
            "keywords": "bone"
        },
        {
            "glyph": "👀",
            "name": "Eyes",
            "keywords": "eyes look see watch"
        },
        {
            "glyph": "👁️",
            "name": "Eye",
            "keywords": "eye"
        },
        {
            "glyph": "👅",
            "name": "Tongue",
            "keywords": "tongue taste"
        },
        {
            "glyph": "👄",
            "name": "Mouth",
            "keywords": "lips kiss"
        },
        {
            "glyph": "🫦",
            "name": "Biting lip",
            "keywords": "biting_lip"
        },
        {
            "glyph": "👶",
            "name": "Baby",
            "keywords": "baby child newborn"
        },
        {
            "glyph": "🧒",
            "name": "Child",
            "keywords": "child"
        },
        {
            "glyph": "👦",
            "name": "Boy",
            "keywords": "boy child"
        },
        {
            "glyph": "👧",
            "name": "Girl",
            "keywords": "girl child"
        },
        {
            "glyph": "🧑",
            "name": "Person",
            "keywords": "adult"
        },
        {
            "glyph": "👱",
            "name": "Person: blond hair",
            "keywords": "blond_haired_person"
        },
        {
            "glyph": "👨",
            "name": "Man",
            "keywords": "man mustache father dad"
        },
        {
            "glyph": "🧔",
            "name": "Person: beard",
            "keywords": "bearded_person"
        },
        {
            "glyph": "🧔‍♂️",
            "name": "Man: beard",
            "keywords": "man_beard"
        },
        {
            "glyph": "🧔‍♀️",
            "name": "Woman: beard",
            "keywords": "woman_beard"
        },
        {
            "glyph": "👨‍🦰",
            "name": "Man: red hair",
            "keywords": "red_haired_man"
        },
        {
            "glyph": "👨‍🦱",
            "name": "Man: curly hair",
            "keywords": "curly_haired_man"
        },
        {
            "glyph": "👨‍🦳",
            "name": "Man: white hair",
            "keywords": "white_haired_man"
        },
        {
            "glyph": "👨‍🦲",
            "name": "Man: bald",
            "keywords": "bald_man"
        },
        {
            "glyph": "👩",
            "name": "Woman",
            "keywords": "woman girls"
        },
        {
            "glyph": "👩‍🦰",
            "name": "Woman: red hair",
            "keywords": "red_haired_woman"
        },
        {
            "glyph": "🧑‍🦰",
            "name": "Person: red hair",
            "keywords": "person_red_hair"
        },
        {
            "glyph": "👩‍🦱",
            "name": "Woman: curly hair",
            "keywords": "curly_haired_woman"
        },
        {
            "glyph": "🧑‍🦱",
            "name": "Person: curly hair",
            "keywords": "person_curly_hair"
        },
        {
            "glyph": "👩‍🦳",
            "name": "Woman: white hair",
            "keywords": "white_haired_woman"
        },
        {
            "glyph": "🧑‍🦳",
            "name": "Person: white hair",
            "keywords": "person_white_hair"
        },
        {
            "glyph": "👩‍🦲",
            "name": "Woman: bald",
            "keywords": "bald_woman"
        },
        {
            "glyph": "🧑‍🦲",
            "name": "Person: bald",
            "keywords": "person_bald"
        },
        {
            "glyph": "👱‍♀️",
            "name": "Woman: blond hair",
            "keywords": "blond_haired_woman blonde_woman"
        },
        {
            "glyph": "👱‍♂️",
            "name": "Man: blond hair",
            "keywords": "blond_haired_man"
        },
        {
            "glyph": "🧓",
            "name": "Older person",
            "keywords": "older_adult"
        },
        {
            "glyph": "👴",
            "name": "Old man",
            "keywords": "older_man"
        },
        {
            "glyph": "👵",
            "name": "Old woman",
            "keywords": "older_woman"
        },
        {
            "glyph": "🙍",
            "name": "Person frowning",
            "keywords": "frowning_person"
        },
        {
            "glyph": "🙍‍♂️",
            "name": "Man frowning",
            "keywords": "frowning_man"
        },
        {
            "glyph": "🙍‍♀️",
            "name": "Woman frowning",
            "keywords": "frowning_woman"
        },
        {
            "glyph": "🙎",
            "name": "Person pouting",
            "keywords": "pouting_face"
        },
        {
            "glyph": "🙎‍♂️",
            "name": "Man pouting",
            "keywords": "pouting_man"
        },
        {
            "glyph": "🙎‍♀️",
            "name": "Woman pouting",
            "keywords": "pouting_woman"
        },
        {
            "glyph": "🙅",
            "name": "Person gesturing no",
            "keywords": "no_good stop halt denied"
        },
        {
            "glyph": "🙅‍♂️",
            "name": "Man gesturing no",
            "keywords": "no_good_man ng_man stop halt denied"
        },
        {
            "glyph": "🙅‍♀️",
            "name": "Woman gesturing no",
            "keywords": "no_good_woman ng_woman stop halt denied"
        },
        {
            "glyph": "🙆",
            "name": "Person gesturing ok",
            "keywords": "ok_person"
        },
        {
            "glyph": "🙆‍♂️",
            "name": "Man gesturing ok",
            "keywords": "ok_man"
        },
        {
            "glyph": "🙆‍♀️",
            "name": "Woman gesturing ok",
            "keywords": "ok_woman"
        },
        {
            "glyph": "💁",
            "name": "Person tipping hand",
            "keywords": "tipping_hand_person information_desk_person"
        },
        {
            "glyph": "💁‍♂️",
            "name": "Man tipping hand",
            "keywords": "tipping_hand_man sassy_man information"
        },
        {
            "glyph": "💁‍♀️",
            "name": "Woman tipping hand",
            "keywords": "tipping_hand_woman sassy_woman information"
        },
        {
            "glyph": "🙋",
            "name": "Person raising hand",
            "keywords": "raising_hand"
        },
        {
            "glyph": "🙋‍♂️",
            "name": "Man raising hand",
            "keywords": "raising_hand_man"
        },
        {
            "glyph": "🙋‍♀️",
            "name": "Woman raising hand",
            "keywords": "raising_hand_woman"
        },
        {
            "glyph": "🧏",
            "name": "Deaf person",
            "keywords": "deaf_person"
        },
        {
            "glyph": "🧏‍♂️",
            "name": "Deaf man",
            "keywords": "deaf_man"
        },
        {
            "glyph": "🧏‍♀️",
            "name": "Deaf woman",
            "keywords": "deaf_woman"
        },
        {
            "glyph": "🙇",
            "name": "Person bowing",
            "keywords": "bow respect thanks"
        },
        {
            "glyph": "🙇‍♂️",
            "name": "Man bowing",
            "keywords": "bowing_man respect thanks"
        },
        {
            "glyph": "🙇‍♀️",
            "name": "Woman bowing",
            "keywords": "bowing_woman respect thanks"
        },
        {
            "glyph": "🤦",
            "name": "Person facepalming",
            "keywords": "facepalm"
        },
        {
            "glyph": "🤦‍♂️",
            "name": "Man facepalming",
            "keywords": "man_facepalming"
        },
        {
            "glyph": "🤦‍♀️",
            "name": "Woman facepalming",
            "keywords": "woman_facepalming"
        },
        {
            "glyph": "🤷",
            "name": "Person shrugging",
            "keywords": "shrug"
        },
        {
            "glyph": "🤷‍♂️",
            "name": "Man shrugging",
            "keywords": "man_shrugging"
        },
        {
            "glyph": "🤷‍♀️",
            "name": "Woman shrugging",
            "keywords": "woman_shrugging"
        },
        {
            "glyph": "🧑‍⚕️",
            "name": "Health worker",
            "keywords": "health_worker"
        },
        {
            "glyph": "👨‍⚕️",
            "name": "Man health worker",
            "keywords": "man_health_worker doctor nurse"
        },
        {
            "glyph": "👩‍⚕️",
            "name": "Woman health worker",
            "keywords": "woman_health_worker doctor nurse"
        },
        {
            "glyph": "🧑‍🎓",
            "name": "Student",
            "keywords": "student"
        },
        {
            "glyph": "👨‍🎓",
            "name": "Man student",
            "keywords": "man_student graduation"
        },
        {
            "glyph": "👩‍🎓",
            "name": "Woman student",
            "keywords": "woman_student graduation"
        },
        {
            "glyph": "🧑‍🏫",
            "name": "Teacher",
            "keywords": "teacher"
        },
        {
            "glyph": "👨‍🏫",
            "name": "Man teacher",
            "keywords": "man_teacher school professor"
        },
        {
            "glyph": "👩‍🏫",
            "name": "Woman teacher",
            "keywords": "woman_teacher school professor"
        },
        {
            "glyph": "🧑‍⚖️",
            "name": "Judge",
            "keywords": "judge"
        },
        {
            "glyph": "👨‍⚖️",
            "name": "Man judge",
            "keywords": "man_judge justice"
        },
        {
            "glyph": "👩‍⚖️",
            "name": "Woman judge",
            "keywords": "woman_judge justice"
        },
        {
            "glyph": "🧑‍🌾",
            "name": "Farmer",
            "keywords": "farmer"
        },
        {
            "glyph": "👨‍🌾",
            "name": "Man farmer",
            "keywords": "man_farmer"
        },
        {
            "glyph": "👩‍🌾",
            "name": "Woman farmer",
            "keywords": "woman_farmer"
        },
        {
            "glyph": "🧑‍🍳",
            "name": "Cook",
            "keywords": "cook"
        },
        {
            "glyph": "👨‍🍳",
            "name": "Man cook",
            "keywords": "man_cook chef"
        },
        {
            "glyph": "👩‍🍳",
            "name": "Woman cook",
            "keywords": "woman_cook chef"
        },
        {
            "glyph": "🧑‍🔧",
            "name": "Mechanic",
            "keywords": "mechanic"
        },
        {
            "glyph": "👨‍🔧",
            "name": "Man mechanic",
            "keywords": "man_mechanic"
        },
        {
            "glyph": "👩‍🔧",
            "name": "Woman mechanic",
            "keywords": "woman_mechanic"
        },
        {
            "glyph": "🧑‍🏭",
            "name": "Factory worker",
            "keywords": "factory_worker"
        },
        {
            "glyph": "👨‍🏭",
            "name": "Man factory worker",
            "keywords": "man_factory_worker"
        },
        {
            "glyph": "👩‍🏭",
            "name": "Woman factory worker",
            "keywords": "woman_factory_worker"
        },
        {
            "glyph": "🧑‍💼",
            "name": "Office worker",
            "keywords": "office_worker"
        },
        {
            "glyph": "👨‍💼",
            "name": "Man office worker",
            "keywords": "man_office_worker business"
        },
        {
            "glyph": "👩‍💼",
            "name": "Woman office worker",
            "keywords": "woman_office_worker business"
        },
        {
            "glyph": "🧑‍🔬",
            "name": "Scientist",
            "keywords": "scientist"
        },
        {
            "glyph": "👨‍🔬",
            "name": "Man scientist",
            "keywords": "man_scientist research"
        },
        {
            "glyph": "👩‍🔬",
            "name": "Woman scientist",
            "keywords": "woman_scientist research"
        },
        {
            "glyph": "🧑‍💻",
            "name": "Technologist",
            "keywords": "technologist"
        },
        {
            "glyph": "👨‍💻",
            "name": "Man technologist",
            "keywords": "man_technologist coder"
        },
        {
            "glyph": "👩‍💻",
            "name": "Woman technologist",
            "keywords": "woman_technologist coder"
        },
        {
            "glyph": "🧑‍🎤",
            "name": "Singer",
            "keywords": "singer"
        },
        {
            "glyph": "👨‍🎤",
            "name": "Man singer",
            "keywords": "man_singer rockstar"
        },
        {
            "glyph": "👩‍🎤",
            "name": "Woman singer",
            "keywords": "woman_singer rockstar"
        },
        {
            "glyph": "🧑‍🎨",
            "name": "Artist",
            "keywords": "artist"
        },
        {
            "glyph": "👨‍🎨",
            "name": "Man artist",
            "keywords": "man_artist painter"
        },
        {
            "glyph": "👩‍🎨",
            "name": "Woman artist",
            "keywords": "woman_artist painter"
        },
        {
            "glyph": "🧑‍✈️",
            "name": "Pilot",
            "keywords": "pilot"
        },
        {
            "glyph": "👨‍✈️",
            "name": "Man pilot",
            "keywords": "man_pilot"
        },
        {
            "glyph": "👩‍✈️",
            "name": "Woman pilot",
            "keywords": "woman_pilot"
        },
        {
            "glyph": "🧑‍🚀",
            "name": "Astronaut",
            "keywords": "astronaut"
        },
        {
            "glyph": "👨‍🚀",
            "name": "Man astronaut",
            "keywords": "man_astronaut space"
        },
        {
            "glyph": "👩‍🚀",
            "name": "Woman astronaut",
            "keywords": "woman_astronaut space"
        },
        {
            "glyph": "🧑‍🚒",
            "name": "Firefighter",
            "keywords": "firefighter"
        },
        {
            "glyph": "👨‍🚒",
            "name": "Man firefighter",
            "keywords": "man_firefighter"
        },
        {
            "glyph": "👩‍🚒",
            "name": "Woman firefighter",
            "keywords": "woman_firefighter"
        },
        {
            "glyph": "👮",
            "name": "Police officer",
            "keywords": "police_officer cop law"
        },
        {
            "glyph": "👮‍♂️",
            "name": "Man police officer",
            "keywords": "policeman law cop"
        },
        {
            "glyph": "👮‍♀️",
            "name": "Woman police officer",
            "keywords": "policewoman law cop"
        },
        {
            "glyph": "🕵️",
            "name": "Detective",
            "keywords": "detective sleuth"
        },
        {
            "glyph": "🕵️‍♂️",
            "name": "Man detective",
            "keywords": "male_detective sleuth"
        },
        {
            "glyph": "🕵️‍♀️",
            "name": "Woman detective",
            "keywords": "female_detective sleuth"
        },
        {
            "glyph": "💂",
            "name": "Guard",
            "keywords": "guard"
        },
        {
            "glyph": "💂‍♂️",
            "name": "Man guard",
            "keywords": "guardsman"
        },
        {
            "glyph": "💂‍♀️",
            "name": "Woman guard",
            "keywords": "guardswoman"
        },
        {
            "glyph": "🥷",
            "name": "Ninja",
            "keywords": "ninja"
        },
        {
            "glyph": "👷",
            "name": "Construction worker",
            "keywords": "construction_worker helmet"
        },
        {
            "glyph": "👷‍♂️",
            "name": "Man construction worker",
            "keywords": "construction_worker_man helmet"
        },
        {
            "glyph": "👷‍♀️",
            "name": "Woman construction worker",
            "keywords": "construction_worker_woman helmet"
        },
        {
            "glyph": "🫅",
            "name": "Person with crown",
            "keywords": "person_with_crown"
        },
        {
            "glyph": "🤴",
            "name": "Prince",
            "keywords": "prince crown royal"
        },
        {
            "glyph": "👸",
            "name": "Princess",
            "keywords": "princess crown royal"
        },
        {
            "glyph": "👳",
            "name": "Person wearing turban",
            "keywords": "person_with_turban"
        },
        {
            "glyph": "👳‍♂️",
            "name": "Man wearing turban",
            "keywords": "man_with_turban"
        },
        {
            "glyph": "👳‍♀️",
            "name": "Woman wearing turban",
            "keywords": "woman_with_turban"
        },
        {
            "glyph": "👲",
            "name": "Person with skullcap",
            "keywords": "man_with_gua_pi_mao"
        },
        {
            "glyph": "🧕",
            "name": "Woman with headscarf",
            "keywords": "woman_with_headscarf hijab"
        },
        {
            "glyph": "🤵",
            "name": "Person in tuxedo",
            "keywords": "person_in_tuxedo groom marriage wedding"
        },
        {
            "glyph": "🤵‍♂️",
            "name": "Man in tuxedo",
            "keywords": "man_in_tuxedo"
        },
        {
            "glyph": "🤵‍♀️",
            "name": "Woman in tuxedo",
            "keywords": "woman_in_tuxedo"
        },
        {
            "glyph": "👰",
            "name": "Person with veil",
            "keywords": "person_with_veil marriage wedding"
        },
        {
            "glyph": "👰‍♂️",
            "name": "Man with veil",
            "keywords": "man_with_veil"
        },
        {
            "glyph": "👰‍♀️",
            "name": "Woman with veil",
            "keywords": "woman_with_veil bride_with_veil"
        },
        {
            "glyph": "🤰",
            "name": "Pregnant woman",
            "keywords": "pregnant_woman"
        },
        {
            "glyph": "🫃",
            "name": "Pregnant man",
            "keywords": "pregnant_man"
        },
        {
            "glyph": "🫄",
            "name": "Pregnant person",
            "keywords": "pregnant_person"
        },
        {
            "glyph": "🤱",
            "name": "Breast-feeding",
            "keywords": "breast_feeding nursing"
        },
        {
            "glyph": "👩‍🍼",
            "name": "Woman feeding baby",
            "keywords": "woman_feeding_baby"
        },
        {
            "glyph": "👨‍🍼",
            "name": "Man feeding baby",
            "keywords": "man_feeding_baby"
        },
        {
            "glyph": "🧑‍🍼",
            "name": "Person feeding baby",
            "keywords": "person_feeding_baby"
        },
        {
            "glyph": "👼",
            "name": "Baby angel",
            "keywords": "angel"
        },
        {
            "glyph": "🎅",
            "name": "Santa claus",
            "keywords": "santa christmas"
        },
        {
            "glyph": "🤶",
            "name": "Mrs. claus",
            "keywords": "mrs_claus santa"
        },
        {
            "glyph": "🧑‍🎄",
            "name": "Mx claus",
            "keywords": "mx_claus"
        },
        {
            "glyph": "🦸",
            "name": "Superhero",
            "keywords": "superhero"
        },
        {
            "glyph": "🦸‍♂️",
            "name": "Man superhero",
            "keywords": "superhero_man"
        },
        {
            "glyph": "🦸‍♀️",
            "name": "Woman superhero",
            "keywords": "superhero_woman"
        },
        {
            "glyph": "🦹",
            "name": "Supervillain",
            "keywords": "supervillain"
        },
        {
            "glyph": "🦹‍♂️",
            "name": "Man supervillain",
            "keywords": "supervillain_man"
        },
        {
            "glyph": "🦹‍♀️",
            "name": "Woman supervillain",
            "keywords": "supervillain_woman"
        },
        {
            "glyph": "🧙",
            "name": "Mage",
            "keywords": "mage wizard"
        },
        {
            "glyph": "🧙‍♂️",
            "name": "Man mage",
            "keywords": "mage_man wizard"
        },
        {
            "glyph": "🧙‍♀️",
            "name": "Woman mage",
            "keywords": "mage_woman wizard"
        },
        {
            "glyph": "🧚",
            "name": "Fairy",
            "keywords": "fairy"
        },
        {
            "glyph": "🧚‍♂️",
            "name": "Man fairy",
            "keywords": "fairy_man"
        },
        {
            "glyph": "🧚‍♀️",
            "name": "Woman fairy",
            "keywords": "fairy_woman"
        },
        {
            "glyph": "🧛",
            "name": "Vampire",
            "keywords": "vampire"
        },
        {
            "glyph": "🧛‍♂️",
            "name": "Man vampire",
            "keywords": "vampire_man"
        },
        {
            "glyph": "🧛‍♀️",
            "name": "Woman vampire",
            "keywords": "vampire_woman"
        },
        {
            "glyph": "🧜",
            "name": "Merperson",
            "keywords": "merperson"
        },
        {
            "glyph": "🧜‍♂️",
            "name": "Merman",
            "keywords": "merman"
        },
        {
            "glyph": "🧜‍♀️",
            "name": "Mermaid",
            "keywords": "mermaid"
        },
        {
            "glyph": "🧝",
            "name": "Elf",
            "keywords": "elf"
        },
        {
            "glyph": "🧝‍♂️",
            "name": "Man elf",
            "keywords": "elf_man"
        },
        {
            "glyph": "🧝‍♀️",
            "name": "Woman elf",
            "keywords": "elf_woman"
        },
        {
            "glyph": "🧞",
            "name": "Genie",
            "keywords": "genie"
        },
        {
            "glyph": "🧞‍♂️",
            "name": "Man genie",
            "keywords": "genie_man"
        },
        {
            "glyph": "🧞‍♀️",
            "name": "Woman genie",
            "keywords": "genie_woman"
        },
        {
            "glyph": "🧟",
            "name": "Zombie",
            "keywords": "zombie"
        },
        {
            "glyph": "🧟‍♂️",
            "name": "Man zombie",
            "keywords": "zombie_man"
        },
        {
            "glyph": "🧟‍♀️",
            "name": "Woman zombie",
            "keywords": "zombie_woman"
        },
        {
            "glyph": "🧌",
            "name": "Troll",
            "keywords": "troll"
        },
        {
            "glyph": "💆",
            "name": "Person getting massage",
            "keywords": "massage spa"
        },
        {
            "glyph": "💆‍♂️",
            "name": "Man getting massage",
            "keywords": "massage_man spa"
        },
        {
            "glyph": "💆‍♀️",
            "name": "Woman getting massage",
            "keywords": "massage_woman spa"
        },
        {
            "glyph": "💇",
            "name": "Person getting haircut",
            "keywords": "haircut beauty"
        },
        {
            "glyph": "💇‍♂️",
            "name": "Man getting haircut",
            "keywords": "haircut_man"
        },
        {
            "glyph": "💇‍♀️",
            "name": "Woman getting haircut",
            "keywords": "haircut_woman"
        },
        {
            "glyph": "🚶",
            "name": "Person walking",
            "keywords": "walking"
        },
        {
            "glyph": "🚶‍♂️",
            "name": "Man walking",
            "keywords": "walking_man"
        },
        {
            "glyph": "🚶‍♀️",
            "name": "Woman walking",
            "keywords": "walking_woman"
        },
        {
            "glyph": "🧍",
            "name": "Person standing",
            "keywords": "standing_person"
        },
        {
            "glyph": "🧍‍♂️",
            "name": "Man standing",
            "keywords": "standing_man"
        },
        {
            "glyph": "🧍‍♀️",
            "name": "Woman standing",
            "keywords": "standing_woman"
        },
        {
            "glyph": "🧎",
            "name": "Person kneeling",
            "keywords": "kneeling_person"
        },
        {
            "glyph": "🧎‍♂️",
            "name": "Man kneeling",
            "keywords": "kneeling_man"
        },
        {
            "glyph": "🧎‍♀️",
            "name": "Woman kneeling",
            "keywords": "kneeling_woman"
        },
        {
            "glyph": "🧑‍🦯",
            "name": "Person with white cane",
            "keywords": "person_with_probing_cane"
        },
        {
            "glyph": "👨‍🦯",
            "name": "Man with white cane",
            "keywords": "man_with_probing_cane"
        },
        {
            "glyph": "👩‍🦯",
            "name": "Woman with white cane",
            "keywords": "woman_with_probing_cane"
        },
        {
            "glyph": "🧑‍🦼",
            "name": "Person in motorized wheelchair",
            "keywords": "person_in_motorized_wheelchair"
        },
        {
            "glyph": "👨‍🦼",
            "name": "Man in motorized wheelchair",
            "keywords": "man_in_motorized_wheelchair"
        },
        {
            "glyph": "👩‍🦼",
            "name": "Woman in motorized wheelchair",
            "keywords": "woman_in_motorized_wheelchair"
        },
        {
            "glyph": "🧑‍🦽",
            "name": "Person in manual wheelchair",
            "keywords": "person_in_manual_wheelchair"
        },
        {
            "glyph": "👨‍🦽",
            "name": "Man in manual wheelchair",
            "keywords": "man_in_manual_wheelchair"
        },
        {
            "glyph": "👩‍🦽",
            "name": "Woman in manual wheelchair",
            "keywords": "woman_in_manual_wheelchair"
        },
        {
            "glyph": "🏃",
            "name": "Person running",
            "keywords": "runner running exercise workout marathon"
        },
        {
            "glyph": "🏃‍♂️",
            "name": "Man running",
            "keywords": "running_man exercise workout marathon"
        },
        {
            "glyph": "🏃‍♀️",
            "name": "Woman running",
            "keywords": "running_woman exercise workout marathon"
        },
        {
            "glyph": "💃",
            "name": "Woman dancing",
            "keywords": "woman_dancing dancer dress"
        },
        {
            "glyph": "🕺",
            "name": "Man dancing",
            "keywords": "man_dancing dancer"
        },
        {
            "glyph": "🕴️",
            "name": "Person in suit levitating",
            "keywords": "business_suit_levitating"
        },
        {
            "glyph": "👯",
            "name": "People with bunny ears",
            "keywords": "dancers bunny"
        },
        {
            "glyph": "👯‍♂️",
            "name": "Men with bunny ears",
            "keywords": "dancing_men bunny"
        },
        {
            "glyph": "👯‍♀️",
            "name": "Women with bunny ears",
            "keywords": "dancing_women bunny"
        },
        {
            "glyph": "🧖",
            "name": "Person in steamy room",
            "keywords": "sauna_person steamy"
        },
        {
            "glyph": "🧖‍♂️",
            "name": "Man in steamy room",
            "keywords": "sauna_man steamy"
        },
        {
            "glyph": "🧖‍♀️",
            "name": "Woman in steamy room",
            "keywords": "sauna_woman steamy"
        },
        {
            "glyph": "🧗",
            "name": "Person climbing",
            "keywords": "climbing bouldering"
        },
        {
            "glyph": "🧗‍♂️",
            "name": "Man climbing",
            "keywords": "climbing_man bouldering"
        },
        {
            "glyph": "🧗‍♀️",
            "name": "Woman climbing",
            "keywords": "climbing_woman bouldering"
        },
        {
            "glyph": "🤺",
            "name": "Person fencing",
            "keywords": "person_fencing"
        },
        {
            "glyph": "🏇",
            "name": "Horse racing",
            "keywords": "horse_racing"
        },
        {
            "glyph": "⛷️",
            "name": "Skier",
            "keywords": "skier"
        },
        {
            "glyph": "🏂",
            "name": "Snowboarder",
            "keywords": "snowboarder"
        },
        {
            "glyph": "🏌️",
            "name": "Person golfing",
            "keywords": "golfing"
        },
        {
            "glyph": "🏌️‍♂️",
            "name": "Man golfing",
            "keywords": "golfing_man"
        },
        {
            "glyph": "🏌️‍♀️",
            "name": "Woman golfing",
            "keywords": "golfing_woman"
        },
        {
            "glyph": "🏄",
            "name": "Person surfing",
            "keywords": "surfer"
        },
        {
            "glyph": "🏄‍♂️",
            "name": "Man surfing",
            "keywords": "surfing_man"
        },
        {
            "glyph": "🏄‍♀️",
            "name": "Woman surfing",
            "keywords": "surfing_woman"
        },
        {
            "glyph": "🚣",
            "name": "Person rowing boat",
            "keywords": "rowboat"
        },
        {
            "glyph": "🚣‍♂️",
            "name": "Man rowing boat",
            "keywords": "rowing_man"
        },
        {
            "glyph": "🚣‍♀️",
            "name": "Woman rowing boat",
            "keywords": "rowing_woman"
        },
        {
            "glyph": "🏊",
            "name": "Person swimming",
            "keywords": "swimmer"
        },
        {
            "glyph": "🏊‍♂️",
            "name": "Man swimming",
            "keywords": "swimming_man"
        },
        {
            "glyph": "🏊‍♀️",
            "name": "Woman swimming",
            "keywords": "swimming_woman"
        },
        {
            "glyph": "⛹️",
            "name": "Person bouncing ball",
            "keywords": "bouncing_ball_person basketball"
        },
        {
            "glyph": "⛹️‍♂️",
            "name": "Man bouncing ball",
            "keywords": "bouncing_ball_man basketball_man"
        },
        {
            "glyph": "⛹️‍♀️",
            "name": "Woman bouncing ball",
            "keywords": "bouncing_ball_woman basketball_woman"
        },
        {
            "glyph": "🏋️",
            "name": "Person lifting weights",
            "keywords": "weight_lifting gym workout"
        },
        {
            "glyph": "🏋️‍♂️",
            "name": "Man lifting weights",
            "keywords": "weight_lifting_man gym workout"
        },
        {
            "glyph": "🏋️‍♀️",
            "name": "Woman lifting weights",
            "keywords": "weight_lifting_woman gym workout"
        },
        {
            "glyph": "🚴",
            "name": "Person biking",
            "keywords": "bicyclist"
        },
        {
            "glyph": "🚴‍♂️",
            "name": "Man biking",
            "keywords": "biking_man"
        },
        {
            "glyph": "🚴‍♀️",
            "name": "Woman biking",
            "keywords": "biking_woman"
        },
        {
            "glyph": "🚵",
            "name": "Person mountain biking",
            "keywords": "mountain_bicyclist"
        },
        {
            "glyph": "🚵‍♂️",
            "name": "Man mountain biking",
            "keywords": "mountain_biking_man"
        },
        {
            "glyph": "🚵‍♀️",
            "name": "Woman mountain biking",
            "keywords": "mountain_biking_woman"
        },
        {
            "glyph": "🤸",
            "name": "Person cartwheeling",
            "keywords": "cartwheeling"
        },
        {
            "glyph": "🤸‍♂️",
            "name": "Man cartwheeling",
            "keywords": "man_cartwheeling"
        },
        {
            "glyph": "🤸‍♀️",
            "name": "Woman cartwheeling",
            "keywords": "woman_cartwheeling"
        },
        {
            "glyph": "🤼",
            "name": "People wrestling",
            "keywords": "wrestling"
        },
        {
            "glyph": "🤼‍♂️",
            "name": "Men wrestling",
            "keywords": "men_wrestling"
        },
        {
            "glyph": "🤼‍♀️",
            "name": "Women wrestling",
            "keywords": "women_wrestling"
        },
        {
            "glyph": "🤽",
            "name": "Person playing water polo",
            "keywords": "water_polo"
        },
        {
            "glyph": "🤽‍♂️",
            "name": "Man playing water polo",
            "keywords": "man_playing_water_polo"
        },
        {
            "glyph": "🤽‍♀️",
            "name": "Woman playing water polo",
            "keywords": "woman_playing_water_polo"
        },
        {
            "glyph": "🤾",
            "name": "Person playing handball",
            "keywords": "handball_person"
        },
        {
            "glyph": "🤾‍♂️",
            "name": "Man playing handball",
            "keywords": "man_playing_handball"
        },
        {
            "glyph": "🤾‍♀️",
            "name": "Woman playing handball",
            "keywords": "woman_playing_handball"
        },
        {
            "glyph": "🤹",
            "name": "Person juggling",
            "keywords": "juggling_person"
        },
        {
            "glyph": "🤹‍♂️",
            "name": "Man juggling",
            "keywords": "man_juggling"
        },
        {
            "glyph": "🤹‍♀️",
            "name": "Woman juggling",
            "keywords": "woman_juggling"
        },
        {
            "glyph": "🧘",
            "name": "Person in lotus position",
            "keywords": "lotus_position meditation"
        },
        {
            "glyph": "🧘‍♂️",
            "name": "Man in lotus position",
            "keywords": "lotus_position_man meditation"
        },
        {
            "glyph": "🧘‍♀️",
            "name": "Woman in lotus position",
            "keywords": "lotus_position_woman meditation"
        },
        {
            "glyph": "🛀",
            "name": "Person taking bath",
            "keywords": "bath shower"
        },
        {
            "glyph": "🛌",
            "name": "Person in bed",
            "keywords": "sleeping_bed"
        },
        {
            "glyph": "🧑‍🤝‍🧑",
            "name": "People holding hands",
            "keywords": "people_holding_hands couple date"
        },
        {
            "glyph": "👭",
            "name": "Women holding hands",
            "keywords": "two_women_holding_hands couple date"
        },
        {
            "glyph": "👫",
            "name": "Woman and man holding hands",
            "keywords": "couple date"
        },
        {
            "glyph": "👬",
            "name": "Men holding hands",
            "keywords": "two_men_holding_hands couple date"
        },
        {
            "glyph": "💏",
            "name": "Kiss",
            "keywords": "couplekiss"
        },
        {
            "glyph": "👩‍❤️‍💋‍👨",
            "name": "Kiss: woman, man",
            "keywords": "couplekiss_man_woman"
        },
        {
            "glyph": "👨‍❤️‍💋‍👨",
            "name": "Kiss: man, man",
            "keywords": "couplekiss_man_man"
        },
        {
            "glyph": "👩‍❤️‍💋‍👩",
            "name": "Kiss: woman, woman",
            "keywords": "couplekiss_woman_woman"
        },
        {
            "glyph": "💑",
            "name": "Couple with heart",
            "keywords": "couple_with_heart"
        },
        {
            "glyph": "👩‍❤️‍👨",
            "name": "Couple with heart: woman, man",
            "keywords": "couple_with_heart_woman_man"
        },
        {
            "glyph": "👨‍❤️‍👨",
            "name": "Couple with heart: man, man",
            "keywords": "couple_with_heart_man_man"
        },
        {
            "glyph": "👩‍❤️‍👩",
            "name": "Couple with heart: woman, woman",
            "keywords": "couple_with_heart_woman_woman"
        },
        {
            "glyph": "👪",
            "name": "Family",
            "keywords": "family home parents child"
        },
        {
            "glyph": "👨‍👩‍👦",
            "name": "Family: man, woman, boy",
            "keywords": "family_man_woman_boy"
        },
        {
            "glyph": "👨‍👩‍👧",
            "name": "Family: man, woman, girl",
            "keywords": "family_man_woman_girl"
        },
        {
            "glyph": "👨‍👩‍👧‍👦",
            "name": "Family: man, woman, girl, boy",
            "keywords": "family_man_woman_girl_boy"
        },
        {
            "glyph": "👨‍👩‍👦‍👦",
            "name": "Family: man, woman, boy, boy",
            "keywords": "family_man_woman_boy_boy"
        },
        {
            "glyph": "👨‍👩‍👧‍👧",
            "name": "Family: man, woman, girl, girl",
            "keywords": "family_man_woman_girl_girl"
        },
        {
            "glyph": "👨‍👨‍👦",
            "name": "Family: man, man, boy",
            "keywords": "family_man_man_boy"
        },
        {
            "glyph": "👨‍👨‍👧",
            "name": "Family: man, man, girl",
            "keywords": "family_man_man_girl"
        },
        {
            "glyph": "👨‍👨‍👧‍👦",
            "name": "Family: man, man, girl, boy",
            "keywords": "family_man_man_girl_boy"
        },
        {
            "glyph": "👨‍👨‍👦‍👦",
            "name": "Family: man, man, boy, boy",
            "keywords": "family_man_man_boy_boy"
        },
        {
            "glyph": "👨‍👨‍👧‍👧",
            "name": "Family: man, man, girl, girl",
            "keywords": "family_man_man_girl_girl"
        },
        {
            "glyph": "👩‍👩‍👦",
            "name": "Family: woman, woman, boy",
            "keywords": "family_woman_woman_boy"
        },
        {
            "glyph": "👩‍👩‍👧",
            "name": "Family: woman, woman, girl",
            "keywords": "family_woman_woman_girl"
        },
        {
            "glyph": "👩‍👩‍👧‍👦",
            "name": "Family: woman, woman, girl, boy",
            "keywords": "family_woman_woman_girl_boy"
        },
        {
            "glyph": "👩‍👩‍👦‍👦",
            "name": "Family: woman, woman, boy, boy",
            "keywords": "family_woman_woman_boy_boy"
        },
        {
            "glyph": "👩‍👩‍👧‍👧",
            "name": "Family: woman, woman, girl, girl",
            "keywords": "family_woman_woman_girl_girl"
        },
        {
            "glyph": "👨‍👦",
            "name": "Family: man, boy",
            "keywords": "family_man_boy"
        },
        {
            "glyph": "👨‍👦‍👦",
            "name": "Family: man, boy, boy",
            "keywords": "family_man_boy_boy"
        },
        {
            "glyph": "👨‍👧",
            "name": "Family: man, girl",
            "keywords": "family_man_girl"
        },
        {
            "glyph": "👨‍👧‍👦",
            "name": "Family: man, girl, boy",
            "keywords": "family_man_girl_boy"
        },
        {
            "glyph": "👨‍👧‍👧",
            "name": "Family: man, girl, girl",
            "keywords": "family_man_girl_girl"
        },
        {
            "glyph": "👩‍👦",
            "name": "Family: woman, boy",
            "keywords": "family_woman_boy"
        },
        {
            "glyph": "👩‍👦‍👦",
            "name": "Family: woman, boy, boy",
            "keywords": "family_woman_boy_boy"
        },
        {
            "glyph": "👩‍👧",
            "name": "Family: woman, girl",
            "keywords": "family_woman_girl"
        },
        {
            "glyph": "👩‍👧‍👦",
            "name": "Family: woman, girl, boy",
            "keywords": "family_woman_girl_boy"
        },
        {
            "glyph": "👩‍👧‍👧",
            "name": "Family: woman, girl, girl",
            "keywords": "family_woman_girl_girl"
        },
        {
            "glyph": "🗣️",
            "name": "Speaking head",
            "keywords": "speaking_head"
        },
        {
            "glyph": "👤",
            "name": "Bust in silhouette",
            "keywords": "bust_in_silhouette user"
        },
        {
            "glyph": "👥",
            "name": "Busts in silhouette",
            "keywords": "busts_in_silhouette users group team"
        },
        {
            "glyph": "🫂",
            "name": "People hugging",
            "keywords": "people_hugging"
        },
        {
            "glyph": "👣",
            "name": "Footprints",
            "keywords": "footprints feet tracks"
        },
        {
            "glyph": "🐵",
            "name": "Monkey face",
            "keywords": "monkey_face"
        },
        {
            "glyph": "🐒",
            "name": "Monkey",
            "keywords": "monkey"
        },
        {
            "glyph": "🦍",
            "name": "Gorilla",
            "keywords": "gorilla"
        },
        {
            "glyph": "🦧",
            "name": "Orangutan",
            "keywords": "orangutan"
        },
        {
            "glyph": "🐶",
            "name": "Dog face",
            "keywords": "dog pet"
        },
        {
            "glyph": "🐕",
            "name": "Dog",
            "keywords": "dog2"
        },
        {
            "glyph": "🦮",
            "name": "Guide dog",
            "keywords": "guide_dog"
        },
        {
            "glyph": "🐕‍🦺",
            "name": "Service dog",
            "keywords": "service_dog"
        },
        {
            "glyph": "🐩",
            "name": "Poodle",
            "keywords": "poodle dog"
        },
        {
            "glyph": "🐺",
            "name": "Wolf",
            "keywords": "wolf"
        },
        {
            "glyph": "🦊",
            "name": "Fox",
            "keywords": "fox_face"
        },
        {
            "glyph": "🦝",
            "name": "Raccoon",
            "keywords": "raccoon"
        },
        {
            "glyph": "🐱",
            "name": "Cat face",
            "keywords": "cat pet"
        },
        {
            "glyph": "🐈",
            "name": "Cat",
            "keywords": "cat2"
        },
        {
            "glyph": "🐈‍⬛",
            "name": "Black cat",
            "keywords": "black_cat"
        },
        {
            "glyph": "🦁",
            "name": "Lion",
            "keywords": "lion"
        },
        {
            "glyph": "🐯",
            "name": "Tiger face",
            "keywords": "tiger"
        },
        {
            "glyph": "🐅",
            "name": "Tiger",
            "keywords": "tiger2"
        },
        {
            "glyph": "🐆",
            "name": "Leopard",
            "keywords": "leopard"
        },
        {
            "glyph": "🐴",
            "name": "Horse face",
            "keywords": "horse"
        },
        {
            "glyph": "🫎",
            "name": "Moose",
            "keywords": "moose canada"
        },
        {
            "glyph": "🫏",
            "name": "Donkey",
            "keywords": "donkey mule"
        },
        {
            "glyph": "🐎",
            "name": "Horse",
            "keywords": "racehorse speed"
        },
        {
            "glyph": "🦄",
            "name": "Unicorn",
            "keywords": "unicorn"
        },
        {
            "glyph": "🦓",
            "name": "Zebra",
            "keywords": "zebra"
        },
        {
            "glyph": "🦌",
            "name": "Deer",
            "keywords": "deer"
        },
        {
            "glyph": "🦬",
            "name": "Bison",
            "keywords": "bison"
        },
        {
            "glyph": "🐮",
            "name": "Cow face",
            "keywords": "cow"
        },
        {
            "glyph": "🐂",
            "name": "Ox",
            "keywords": "ox"
        },
        {
            "glyph": "🐃",
            "name": "Water buffalo",
            "keywords": "water_buffalo"
        },
        {
            "glyph": "🐄",
            "name": "Cow",
            "keywords": "cow2"
        },
        {
            "glyph": "🐷",
            "name": "Pig face",
            "keywords": "pig"
        },
        {
            "glyph": "🐖",
            "name": "Pig",
            "keywords": "pig2"
        },
        {
            "glyph": "🐗",
            "name": "Boar",
            "keywords": "boar"
        },
        {
            "glyph": "🐽",
            "name": "Pig nose",
            "keywords": "pig_nose"
        },
        {
            "glyph": "🐏",
            "name": "Ram",
            "keywords": "ram"
        },
        {
            "glyph": "🐑",
            "name": "Ewe",
            "keywords": "sheep"
        },
        {
            "glyph": "🐐",
            "name": "Goat",
            "keywords": "goat"
        },
        {
            "glyph": "🐪",
            "name": "Camel",
            "keywords": "dromedary_camel desert"
        },
        {
            "glyph": "🐫",
            "name": "Two-hump camel",
            "keywords": "camel"
        },
        {
            "glyph": "🦙",
            "name": "Llama",
            "keywords": "llama"
        },
        {
            "glyph": "🦒",
            "name": "Giraffe",
            "keywords": "giraffe"
        },
        {
            "glyph": "🐘",
            "name": "Elephant",
            "keywords": "elephant"
        },
        {
            "glyph": "🦣",
            "name": "Mammoth",
            "keywords": "mammoth"
        },
        {
            "glyph": "🦏",
            "name": "Rhinoceros",
            "keywords": "rhinoceros"
        },
        {
            "glyph": "🦛",
            "name": "Hippopotamus",
            "keywords": "hippopotamus"
        },
        {
            "glyph": "🐭",
            "name": "Mouse face",
            "keywords": "mouse"
        },
        {
            "glyph": "🐁",
            "name": "Mouse",
            "keywords": "mouse2"
        },
        {
            "glyph": "🐀",
            "name": "Rat",
            "keywords": "rat"
        },
        {
            "glyph": "🐹",
            "name": "Hamster",
            "keywords": "hamster pet"
        },
        {
            "glyph": "🐰",
            "name": "Rabbit face",
            "keywords": "rabbit bunny"
        },
        {
            "glyph": "🐇",
            "name": "Rabbit",
            "keywords": "rabbit2"
        },
        {
            "glyph": "🐿️",
            "name": "Chipmunk",
            "keywords": "chipmunk"
        },
        {
            "glyph": "🦫",
            "name": "Beaver",
            "keywords": "beaver"
        },
        {
            "glyph": "🦔",
            "name": "Hedgehog",
            "keywords": "hedgehog"
        },
        {
            "glyph": "🦇",
            "name": "Bat",
            "keywords": "bat"
        },
        {
            "glyph": "🐻",
            "name": "Bear",
            "keywords": "bear"
        },
        {
            "glyph": "🐻‍❄️",
            "name": "Polar bear",
            "keywords": "polar_bear"
        },
        {
            "glyph": "🐨",
            "name": "Koala",
            "keywords": "koala"
        },
        {
            "glyph": "🐼",
            "name": "Panda",
            "keywords": "panda_face"
        },
        {
            "glyph": "🦥",
            "name": "Sloth",
            "keywords": "sloth"
        },
        {
            "glyph": "🦦",
            "name": "Otter",
            "keywords": "otter"
        },
        {
            "glyph": "🦨",
            "name": "Skunk",
            "keywords": "skunk"
        },
        {
            "glyph": "🦘",
            "name": "Kangaroo",
            "keywords": "kangaroo"
        },
        {
            "glyph": "🦡",
            "name": "Badger",
            "keywords": "badger"
        },
        {
            "glyph": "🐾",
            "name": "Paw prints",
            "keywords": "feet paw_prints"
        },
        {
            "glyph": "🦃",
            "name": "Turkey",
            "keywords": "turkey thanksgiving"
        },
        {
            "glyph": "🐔",
            "name": "Chicken",
            "keywords": "chicken"
        },
        {
            "glyph": "🐓",
            "name": "Rooster",
            "keywords": "rooster"
        },
        {
            "glyph": "🐣",
            "name": "Hatching chick",
            "keywords": "hatching_chick"
        },
        {
            "glyph": "🐤",
            "name": "Baby chick",
            "keywords": "baby_chick"
        },
        {
            "glyph": "🐥",
            "name": "Front-facing baby chick",
            "keywords": "hatched_chick"
        },
        {
            "glyph": "🐦",
            "name": "Bird",
            "keywords": "bird"
        },
        {
            "glyph": "🐧",
            "name": "Penguin",
            "keywords": "penguin"
        },
        {
            "glyph": "🕊️",
            "name": "Dove",
            "keywords": "dove peace"
        },
        {
            "glyph": "🦅",
            "name": "Eagle",
            "keywords": "eagle"
        },
        {
            "glyph": "🦆",
            "name": "Duck",
            "keywords": "duck"
        },
        {
            "glyph": "🦢",
            "name": "Swan",
            "keywords": "swan"
        },
        {
            "glyph": "🦉",
            "name": "Owl",
            "keywords": "owl"
        },
        {
            "glyph": "🦤",
            "name": "Dodo",
            "keywords": "dodo"
        },
        {
            "glyph": "🪶",
            "name": "Feather",
            "keywords": "feather"
        },
        {
            "glyph": "🦩",
            "name": "Flamingo",
            "keywords": "flamingo"
        },
        {
            "glyph": "🦚",
            "name": "Peacock",
            "keywords": "peacock"
        },
        {
            "glyph": "🦜",
            "name": "Parrot",
            "keywords": "parrot"
        },
        {
            "glyph": "🪽",
            "name": "Wing",
            "keywords": "wing fly"
        },
        {
            "glyph": "🐦‍⬛",
            "name": "Black bird",
            "keywords": "black_bird"
        },
        {
            "glyph": "🪿",
            "name": "Goose",
            "keywords": "goose honk"
        },
        {
            "glyph": "🐸",
            "name": "Frog",
            "keywords": "frog"
        },
        {
            "glyph": "🐊",
            "name": "Crocodile",
            "keywords": "crocodile"
        },
        {
            "glyph": "🐢",
            "name": "Turtle",
            "keywords": "turtle slow"
        },
        {
            "glyph": "🦎",
            "name": "Lizard",
            "keywords": "lizard"
        },
        {
            "glyph": "🐍",
            "name": "Snake",
            "keywords": "snake"
        },
        {
            "glyph": "🐲",
            "name": "Dragon face",
            "keywords": "dragon_face"
        },
        {
            "glyph": "🐉",
            "name": "Dragon",
            "keywords": "dragon"
        },
        {
            "glyph": "🦕",
            "name": "Sauropod",
            "keywords": "sauropod dinosaur"
        },
        {
            "glyph": "🦖",
            "name": "T-rex",
            "keywords": "t-rex dinosaur"
        },
        {
            "glyph": "🐳",
            "name": "Spouting whale",
            "keywords": "whale sea"
        },
        {
            "glyph": "🐋",
            "name": "Whale",
            "keywords": "whale2"
        },
        {
            "glyph": "🐬",
            "name": "Dolphin",
            "keywords": "dolphin flipper"
        },
        {
            "glyph": "🦭",
            "name": "Seal",
            "keywords": "seal"
        },
        {
            "glyph": "🐟",
            "name": "Fish",
            "keywords": "fish"
        },
        {
            "glyph": "🐠",
            "name": "Tropical fish",
            "keywords": "tropical_fish"
        },
        {
            "glyph": "🐡",
            "name": "Blowfish",
            "keywords": "blowfish"
        },
        {
            "glyph": "🦈",
            "name": "Shark",
            "keywords": "shark"
        },
        {
            "glyph": "🐙",
            "name": "Octopus",
            "keywords": "octopus"
        },
        {
            "glyph": "🐚",
            "name": "Spiral shell",
            "keywords": "shell sea beach"
        },
        {
            "glyph": "🪸",
            "name": "Coral",
            "keywords": "coral"
        },
        {
            "glyph": "🪼",
            "name": "Jellyfish",
            "keywords": "jellyfish"
        },
        {
            "glyph": "🐌",
            "name": "Snail",
            "keywords": "snail slow"
        },
        {
            "glyph": "🦋",
            "name": "Butterfly",
            "keywords": "butterfly"
        },
        {
            "glyph": "🐛",
            "name": "Bug",
            "keywords": "bug"
        },
        {
            "glyph": "🐜",
            "name": "Ant",
            "keywords": "ant"
        },
        {
            "glyph": "🐝",
            "name": "Honeybee",
            "keywords": "bee honeybee"
        },
        {
            "glyph": "🪲",
            "name": "Beetle",
            "keywords": "beetle"
        },
        {
            "glyph": "🐞",
            "name": "Lady beetle",
            "keywords": "lady_beetle bug"
        },
        {
            "glyph": "🦗",
            "name": "Cricket",
            "keywords": "cricket"
        },
        {
            "glyph": "🪳",
            "name": "Cockroach",
            "keywords": "cockroach"
        },
        {
            "glyph": "🕷️",
            "name": "Spider",
            "keywords": "spider"
        },
        {
            "glyph": "🕸️",
            "name": "Spider web",
            "keywords": "spider_web"
        },
        {
            "glyph": "🦂",
            "name": "Scorpion",
            "keywords": "scorpion"
        },
        {
            "glyph": "🦟",
            "name": "Mosquito",
            "keywords": "mosquito"
        },
        {
            "glyph": "🪰",
            "name": "Fly",
            "keywords": "fly"
        },
        {
            "glyph": "🪱",
            "name": "Worm",
            "keywords": "worm"
        },
        {
            "glyph": "🦠",
            "name": "Microbe",
            "keywords": "microbe germ"
        },
        {
            "glyph": "💐",
            "name": "Bouquet",
            "keywords": "bouquet flowers"
        },
        {
            "glyph": "🌸",
            "name": "Cherry blossom",
            "keywords": "cherry_blossom flower spring"
        },
        {
            "glyph": "💮",
            "name": "White flower",
            "keywords": "white_flower"
        },
        {
            "glyph": "🪷",
            "name": "Lotus",
            "keywords": "lotus"
        },
        {
            "glyph": "🏵️",
            "name": "Rosette",
            "keywords": "rosette"
        },
        {
            "glyph": "🌹",
            "name": "Rose",
            "keywords": "rose flower"
        },
        {
            "glyph": "🥀",
            "name": "Wilted flower",
            "keywords": "wilted_flower"
        },
        {
            "glyph": "🌺",
            "name": "Hibiscus",
            "keywords": "hibiscus"
        },
        {
            "glyph": "🌻",
            "name": "Sunflower",
            "keywords": "sunflower"
        },
        {
            "glyph": "🌼",
            "name": "Blossom",
            "keywords": "blossom"
        },
        {
            "glyph": "🌷",
            "name": "Tulip",
            "keywords": "tulip flower"
        },
        {
            "glyph": "🪻",
            "name": "Hyacinth",
            "keywords": "hyacinth"
        },
        {
            "glyph": "🌱",
            "name": "Seedling",
            "keywords": "seedling plant"
        },
        {
            "glyph": "🪴",
            "name": "Potted plant",
            "keywords": "potted_plant"
        },
        {
            "glyph": "🌲",
            "name": "Evergreen tree",
            "keywords": "evergreen_tree wood"
        },
        {
            "glyph": "🌳",
            "name": "Deciduous tree",
            "keywords": "deciduous_tree wood"
        },
        {
            "glyph": "🌴",
            "name": "Palm tree",
            "keywords": "palm_tree"
        },
        {
            "glyph": "🌵",
            "name": "Cactus",
            "keywords": "cactus"
        },
        {
            "glyph": "🌾",
            "name": "Sheaf of rice",
            "keywords": "ear_of_rice"
        },
        {
            "glyph": "🌿",
            "name": "Herb",
            "keywords": "herb"
        },
        {
            "glyph": "☘️",
            "name": "Shamrock",
            "keywords": "shamrock"
        },
        {
            "glyph": "🍀",
            "name": "Four leaf clover",
            "keywords": "four_leaf_clover luck"
        },
        {
            "glyph": "🍁",
            "name": "Maple leaf",
            "keywords": "maple_leaf canada"
        },
        {
            "glyph": "🍂",
            "name": "Fallen leaf",
            "keywords": "fallen_leaf autumn"
        },
        {
            "glyph": "🍃",
            "name": "Leaf fluttering in wind",
            "keywords": "leaves leaf"
        },
        {
            "glyph": "🪹",
            "name": "Empty nest",
            "keywords": "empty_nest"
        },
        {
            "glyph": "🪺",
            "name": "Nest with eggs",
            "keywords": "nest_with_eggs"
        },
        {
            "glyph": "🍄",
            "name": "Mushroom",
            "keywords": "mushroom fungus"
        },
        {
            "glyph": "🍇",
            "name": "Grapes",
            "keywords": "grapes"
        },
        {
            "glyph": "🍈",
            "name": "Melon",
            "keywords": "melon"
        },
        {
            "glyph": "🍉",
            "name": "Watermelon",
            "keywords": "watermelon"
        },
        {
            "glyph": "🍊",
            "name": "Tangerine",
            "keywords": "tangerine orange mandarin"
        },
        {
            "glyph": "🍋",
            "name": "Lemon",
            "keywords": "lemon"
        },
        {
            "glyph": "🍌",
            "name": "Banana",
            "keywords": "banana fruit"
        },
        {
            "glyph": "🍍",
            "name": "Pineapple",
            "keywords": "pineapple"
        },
        {
            "glyph": "🥭",
            "name": "Mango",
            "keywords": "mango"
        },
        {
            "glyph": "🍎",
            "name": "Red apple",
            "keywords": "apple"
        },
        {
            "glyph": "🍏",
            "name": "Green apple",
            "keywords": "green_apple fruit"
        },
        {
            "glyph": "🍐",
            "name": "Pear",
            "keywords": "pear"
        },
        {
            "glyph": "🍑",
            "name": "Peach",
            "keywords": "peach"
        },
        {
            "glyph": "🍒",
            "name": "Cherries",
            "keywords": "cherries fruit"
        },
        {
            "glyph": "🍓",
            "name": "Strawberry",
            "keywords": "strawberry fruit"
        },
        {
            "glyph": "🫐",
            "name": "Blueberries",
            "keywords": "blueberries"
        },
        {
            "glyph": "🥝",
            "name": "Kiwi fruit",
            "keywords": "kiwi_fruit"
        },
        {
            "glyph": "🍅",
            "name": "Tomato",
            "keywords": "tomato"
        },
        {
            "glyph": "🫒",
            "name": "Olive",
            "keywords": "olive"
        },
        {
            "glyph": "🥥",
            "name": "Coconut",
            "keywords": "coconut"
        },
        {
            "glyph": "🥑",
            "name": "Avocado",
            "keywords": "avocado"
        },
        {
            "glyph": "🍆",
            "name": "Eggplant",
            "keywords": "eggplant aubergine"
        },
        {
            "glyph": "🥔",
            "name": "Potato",
            "keywords": "potato"
        },
        {
            "glyph": "🥕",
            "name": "Carrot",
            "keywords": "carrot"
        },
        {
            "glyph": "🌽",
            "name": "Ear of corn",
            "keywords": "corn"
        },
        {
            "glyph": "🌶️",
            "name": "Hot pepper",
            "keywords": "hot_pepper spicy"
        },
        {
            "glyph": "🫑",
            "name": "Bell pepper",
            "keywords": "bell_pepper"
        },
        {
            "glyph": "🥒",
            "name": "Cucumber",
            "keywords": "cucumber"
        },
        {
            "glyph": "🥬",
            "name": "Leafy green",
            "keywords": "leafy_green"
        },
        {
            "glyph": "🥦",
            "name": "Broccoli",
            "keywords": "broccoli"
        },
        {
            "glyph": "🧄",
            "name": "Garlic",
            "keywords": "garlic"
        },
        {
            "glyph": "🧅",
            "name": "Onion",
            "keywords": "onion"
        },
        {
            "glyph": "🥜",
            "name": "Peanuts",
            "keywords": "peanuts"
        },
        {
            "glyph": "🫘",
            "name": "Beans",
            "keywords": "beans"
        },
        {
            "glyph": "🌰",
            "name": "Chestnut",
            "keywords": "chestnut"
        },
        {
            "glyph": "🫚",
            "name": "Ginger root",
            "keywords": "ginger_root"
        },
        {
            "glyph": "🫛",
            "name": "Pea pod",
            "keywords": "pea_pod"
        },
        {
            "glyph": "🍞",
            "name": "Bread",
            "keywords": "bread toast"
        },
        {
            "glyph": "🥐",
            "name": "Croissant",
            "keywords": "croissant"
        },
        {
            "glyph": "🥖",
            "name": "Baguette bread",
            "keywords": "baguette_bread"
        },
        {
            "glyph": "🫓",
            "name": "Flatbread",
            "keywords": "flatbread"
        },
        {
            "glyph": "🥨",
            "name": "Pretzel",
            "keywords": "pretzel"
        },
        {
            "glyph": "🥯",
            "name": "Bagel",
            "keywords": "bagel"
        },
        {
            "glyph": "🥞",
            "name": "Pancakes",
            "keywords": "pancakes"
        },
        {
            "glyph": "🧇",
            "name": "Waffle",
            "keywords": "waffle"
        },
        {
            "glyph": "🧀",
            "name": "Cheese wedge",
            "keywords": "cheese"
        },
        {
            "glyph": "🍖",
            "name": "Meat on bone",
            "keywords": "meat_on_bone"
        },
        {
            "glyph": "🍗",
            "name": "Poultry leg",
            "keywords": "poultry_leg meat chicken"
        },
        {
            "glyph": "🥩",
            "name": "Cut of meat",
            "keywords": "cut_of_meat"
        },
        {
            "glyph": "🥓",
            "name": "Bacon",
            "keywords": "bacon"
        },
        {
            "glyph": "🍔",
            "name": "Hamburger",
            "keywords": "hamburger burger"
        },
        {
            "glyph": "🍟",
            "name": "French fries",
            "keywords": "fries"
        },
        {
            "glyph": "🍕",
            "name": "Pizza",
            "keywords": "pizza"
        },
        {
            "glyph": "🌭",
            "name": "Hot dog",
            "keywords": "hotdog"
        },
        {
            "glyph": "🥪",
            "name": "Sandwich",
            "keywords": "sandwich"
        },
        {
            "glyph": "🌮",
            "name": "Taco",
            "keywords": "taco"
        },
        {
            "glyph": "🌯",
            "name": "Burrito",
            "keywords": "burrito"
        },
        {
            "glyph": "🫔",
            "name": "Tamale",
            "keywords": "tamale"
        },
        {
            "glyph": "🥙",
            "name": "Stuffed flatbread",
            "keywords": "stuffed_flatbread"
        },
        {
            "glyph": "🧆",
            "name": "Falafel",
            "keywords": "falafel"
        },
        {
            "glyph": "🥚",
            "name": "Egg",
            "keywords": "egg"
        },
        {
            "glyph": "🍳",
            "name": "Cooking",
            "keywords": "fried_egg breakfast"
        },
        {
            "glyph": "🥘",
            "name": "Shallow pan of food",
            "keywords": "shallow_pan_of_food paella curry"
        },
        {
            "glyph": "🍲",
            "name": "Pot of food",
            "keywords": "stew"
        },
        {
            "glyph": "🫕",
            "name": "Fondue",
            "keywords": "fondue"
        },
        {
            "glyph": "🥣",
            "name": "Bowl with spoon",
            "keywords": "bowl_with_spoon"
        },
        {
            "glyph": "🥗",
            "name": "Green salad",
            "keywords": "green_salad"
        },
        {
            "glyph": "🍿",
            "name": "Popcorn",
            "keywords": "popcorn"
        },
        {
            "glyph": "🧈",
            "name": "Butter",
            "keywords": "butter"
        },
        {
            "glyph": "🧂",
            "name": "Salt",
            "keywords": "salt"
        },
        {
            "glyph": "🥫",
            "name": "Canned food",
            "keywords": "canned_food"
        },
        {
            "glyph": "🍱",
            "name": "Bento box",
            "keywords": "bento"
        },
        {
            "glyph": "🍘",
            "name": "Rice cracker",
            "keywords": "rice_cracker"
        },
        {
            "glyph": "🍙",
            "name": "Rice ball",
            "keywords": "rice_ball"
        },
        {
            "glyph": "🍚",
            "name": "Cooked rice",
            "keywords": "rice"
        },
        {
            "glyph": "🍛",
            "name": "Curry rice",
            "keywords": "curry"
        },
        {
            "glyph": "🍜",
            "name": "Steaming bowl",
            "keywords": "ramen noodle"
        },
        {
            "glyph": "🍝",
            "name": "Spaghetti",
            "keywords": "spaghetti pasta"
        },
        {
            "glyph": "🍠",
            "name": "Roasted sweet potato",
            "keywords": "sweet_potato"
        },
        {
            "glyph": "🍢",
            "name": "Oden",
            "keywords": "oden"
        },
        {
            "glyph": "🍣",
            "name": "Sushi",
            "keywords": "sushi"
        },
        {
            "glyph": "🍤",
            "name": "Fried shrimp",
            "keywords": "fried_shrimp tempura"
        },
        {
            "glyph": "🍥",
            "name": "Fish cake with swirl",
            "keywords": "fish_cake"
        },
        {
            "glyph": "🥮",
            "name": "Moon cake",
            "keywords": "moon_cake"
        },
        {
            "glyph": "🍡",
            "name": "Dango",
            "keywords": "dango"
        },
        {
            "glyph": "🥟",
            "name": "Dumpling",
            "keywords": "dumpling"
        },
        {
            "glyph": "🥠",
            "name": "Fortune cookie",
            "keywords": "fortune_cookie"
        },
        {
            "glyph": "🥡",
            "name": "Takeout box",
            "keywords": "takeout_box"
        },
        {
            "glyph": "🦀",
            "name": "Crab",
            "keywords": "crab"
        },
        {
            "glyph": "🦞",
            "name": "Lobster",
            "keywords": "lobster"
        },
        {
            "glyph": "🦐",
            "name": "Shrimp",
            "keywords": "shrimp"
        },
        {
            "glyph": "🦑",
            "name": "Squid",
            "keywords": "squid"
        },
        {
            "glyph": "🦪",
            "name": "Oyster",
            "keywords": "oyster"
        },
        {
            "glyph": "🍦",
            "name": "Soft ice cream",
            "keywords": "icecream"
        },
        {
            "glyph": "🍧",
            "name": "Shaved ice",
            "keywords": "shaved_ice"
        },
        {
            "glyph": "🍨",
            "name": "Ice cream",
            "keywords": "ice_cream"
        },
        {
            "glyph": "🍩",
            "name": "Doughnut",
            "keywords": "doughnut"
        },
        {
            "glyph": "🍪",
            "name": "Cookie",
            "keywords": "cookie"
        },
        {
            "glyph": "🎂",
            "name": "Birthday cake",
            "keywords": "birthday party"
        },
        {
            "glyph": "🍰",
            "name": "Shortcake",
            "keywords": "cake dessert"
        },
        {
            "glyph": "🧁",
            "name": "Cupcake",
            "keywords": "cupcake"
        },
        {
            "glyph": "🥧",
            "name": "Pie",
            "keywords": "pie"
        },
        {
            "glyph": "🍫",
            "name": "Chocolate bar",
            "keywords": "chocolate_bar"
        },
        {
            "glyph": "🍬",
            "name": "Candy",
            "keywords": "candy sweet"
        },
        {
            "glyph": "🍭",
            "name": "Lollipop",
            "keywords": "lollipop"
        },
        {
            "glyph": "🍮",
            "name": "Custard",
            "keywords": "custard"
        },
        {
            "glyph": "🍯",
            "name": "Honey pot",
            "keywords": "honey_pot"
        },
        {
            "glyph": "🍼",
            "name": "Baby bottle",
            "keywords": "baby_bottle milk"
        },
        {
            "glyph": "🥛",
            "name": "Glass of milk",
            "keywords": "milk_glass"
        },
        {
            "glyph": "☕",
            "name": "Hot beverage",
            "keywords": "coffee cafe espresso"
        },
        {
            "glyph": "🫖",
            "name": "Teapot",
            "keywords": "teapot"
        },
        {
            "glyph": "🍵",
            "name": "Teacup without handle",
            "keywords": "tea green breakfast"
        },
        {
            "glyph": "🍶",
            "name": "Sake",
            "keywords": "sake"
        },
        {
            "glyph": "🍾",
            "name": "Bottle with popping cork",
            "keywords": "champagne bottle bubbly celebration"
        },
        {
            "glyph": "🍷",
            "name": "Wine glass",
            "keywords": "wine_glass"
        },
        {
            "glyph": "🍸",
            "name": "Cocktail glass",
            "keywords": "cocktail drink"
        },
        {
            "glyph": "🍹",
            "name": "Tropical drink",
            "keywords": "tropical_drink summer vacation"
        },
        {
            "glyph": "🍺",
            "name": "Beer mug",
            "keywords": "beer drink"
        },
        {
            "glyph": "🍻",
            "name": "Clinking beer mugs",
            "keywords": "beers drinks"
        },
        {
            "glyph": "🥂",
            "name": "Clinking glasses",
            "keywords": "clinking_glasses cheers toast"
        },
        {
            "glyph": "🥃",
            "name": "Tumbler glass",
            "keywords": "tumbler_glass whisky"
        },
        {
            "glyph": "🫗",
            "name": "Pouring liquid",
            "keywords": "pouring_liquid"
        },
        {
            "glyph": "🥤",
            "name": "Cup with straw",
            "keywords": "cup_with_straw"
        },
        {
            "glyph": "🧋",
            "name": "Bubble tea",
            "keywords": "bubble_tea"
        },
        {
            "glyph": "🧃",
            "name": "Beverage box",
            "keywords": "beverage_box"
        },
        {
            "glyph": "🧉",
            "name": "Mate",
            "keywords": "mate"
        },
        {
            "glyph": "🧊",
            "name": "Ice",
            "keywords": "ice_cube"
        },
        {
            "glyph": "🥢",
            "name": "Chopsticks",
            "keywords": "chopsticks"
        },
        {
            "glyph": "🍽️",
            "name": "Fork and knife with plate",
            "keywords": "plate_with_cutlery dining dinner"
        },
        {
            "glyph": "🍴",
            "name": "Fork and knife",
            "keywords": "fork_and_knife cutlery"
        },
        {
            "glyph": "🥄",
            "name": "Spoon",
            "keywords": "spoon"
        },
        {
            "glyph": "🔪",
            "name": "Kitchen knife",
            "keywords": "hocho knife cut chop"
        },
        {
            "glyph": "🫙",
            "name": "Jar",
            "keywords": "jar"
        },
        {
            "glyph": "🏺",
            "name": "Amphora",
            "keywords": "amphora"
        },
        {
            "glyph": "🌍",
            "name": "Globe showing europe-africa",
            "keywords": "earth_africa globe world international"
        },
        {
            "glyph": "🌎",
            "name": "Globe showing americas",
            "keywords": "earth_americas globe world international"
        },
        {
            "glyph": "🌏",
            "name": "Globe showing asia-australia",
            "keywords": "earth_asia globe world international"
        },
        {
            "glyph": "🌐",
            "name": "Globe with meridians",
            "keywords": "globe_with_meridians world global international"
        },
        {
            "glyph": "🗺️",
            "name": "World map",
            "keywords": "world_map travel"
        },
        {
            "glyph": "🗾",
            "name": "Map of japan",
            "keywords": "japan"
        },
        {
            "glyph": "🧭",
            "name": "Compass",
            "keywords": "compass"
        },
        {
            "glyph": "🏔️",
            "name": "Snow-capped mountain",
            "keywords": "mountain_snow"
        },
        {
            "glyph": "⛰️",
            "name": "Mountain",
            "keywords": "mountain"
        },
        {
            "glyph": "🌋",
            "name": "Volcano",
            "keywords": "volcano"
        },
        {
            "glyph": "🗻",
            "name": "Mount fuji",
            "keywords": "mount_fuji"
        },
        {
            "glyph": "🏕️",
            "name": "Camping",
            "keywords": "camping"
        },
        {
            "glyph": "🏖️",
            "name": "Beach with umbrella",
            "keywords": "beach_umbrella"
        },
        {
            "glyph": "🏜️",
            "name": "Desert",
            "keywords": "desert"
        },
        {
            "glyph": "🏝️",
            "name": "Desert island",
            "keywords": "desert_island"
        },
        {
            "glyph": "🏞️",
            "name": "National park",
            "keywords": "national_park"
        },
        {
            "glyph": "🏟️",
            "name": "Stadium",
            "keywords": "stadium"
        },
        {
            "glyph": "🏛️",
            "name": "Classical building",
            "keywords": "classical_building"
        },
        {
            "glyph": "🏗️",
            "name": "Building construction",
            "keywords": "building_construction"
        },
        {
            "glyph": "🧱",
            "name": "Brick",
            "keywords": "bricks"
        },
        {
            "glyph": "🪨",
            "name": "Rock",
            "keywords": "rock"
        },
        {
            "glyph": "🪵",
            "name": "Wood",
            "keywords": "wood"
        },
        {
            "glyph": "🛖",
            "name": "Hut",
            "keywords": "hut"
        },
        {
            "glyph": "🏘️",
            "name": "Houses",
            "keywords": "houses"
        },
        {
            "glyph": "🏚️",
            "name": "Derelict house",
            "keywords": "derelict_house"
        },
        {
            "glyph": "🏠",
            "name": "House",
            "keywords": "house"
        },
        {
            "glyph": "🏡",
            "name": "House with garden",
            "keywords": "house_with_garden"
        },
        {
            "glyph": "🏢",
            "name": "Office building",
            "keywords": "office"
        },
        {
            "glyph": "🏣",
            "name": "Japanese post office",
            "keywords": "post_office"
        },
        {
            "glyph": "🏤",
            "name": "Post office",
            "keywords": "european_post_office"
        },
        {
            "glyph": "🏥",
            "name": "Hospital",
            "keywords": "hospital"
        },
        {
            "glyph": "🏦",
            "name": "Bank",
            "keywords": "bank"
        },
        {
            "glyph": "🏨",
            "name": "Hotel",
            "keywords": "hotel"
        },
        {
            "glyph": "🏩",
            "name": "Love hotel",
            "keywords": "love_hotel"
        },
        {
            "glyph": "🏪",
            "name": "Convenience store",
            "keywords": "convenience_store"
        },
        {
            "glyph": "🏫",
            "name": "School",
            "keywords": "school"
        },
        {
            "glyph": "🏬",
            "name": "Department store",
            "keywords": "department_store"
        },
        {
            "glyph": "🏭",
            "name": "Factory",
            "keywords": "factory"
        },
        {
            "glyph": "🏯",
            "name": "Japanese castle",
            "keywords": "japanese_castle"
        },
        {
            "glyph": "🏰",
            "name": "Castle",
            "keywords": "european_castle"
        },
        {
            "glyph": "💒",
            "name": "Wedding",
            "keywords": "wedding marriage"
        },
        {
            "glyph": "🗼",
            "name": "Tokyo tower",
            "keywords": "tokyo_tower"
        },
        {
            "glyph": "🗽",
            "name": "Statue of liberty",
            "keywords": "statue_of_liberty"
        },
        {
            "glyph": "⛪",
            "name": "Church",
            "keywords": "church"
        },
        {
            "glyph": "🕌",
            "name": "Mosque",
            "keywords": "mosque"
        },
        {
            "glyph": "🛕",
            "name": "Hindu temple",
            "keywords": "hindu_temple"
        },
        {
            "glyph": "🕍",
            "name": "Synagogue",
            "keywords": "synagogue"
        },
        {
            "glyph": "⛩️",
            "name": "Shinto shrine",
            "keywords": "shinto_shrine"
        },
        {
            "glyph": "🕋",
            "name": "Kaaba",
            "keywords": "kaaba"
        },
        {
            "glyph": "⛲",
            "name": "Fountain",
            "keywords": "fountain"
        },
        {
            "glyph": "⛺",
            "name": "Tent",
            "keywords": "tent camping"
        },
        {
            "glyph": "🌁",
            "name": "Foggy",
            "keywords": "foggy karl"
        },
        {
            "glyph": "🌃",
            "name": "Night with stars",
            "keywords": "night_with_stars"
        },
        {
            "glyph": "🏙️",
            "name": "Cityscape",
            "keywords": "cityscape skyline"
        },
        {
            "glyph": "🌄",
            "name": "Sunrise over mountains",
            "keywords": "sunrise_over_mountains"
        },
        {
            "glyph": "🌅",
            "name": "Sunrise",
            "keywords": "sunrise"
        },
        {
            "glyph": "🌆",
            "name": "Cityscape at dusk",
            "keywords": "city_sunset"
        },
        {
            "glyph": "🌇",
            "name": "Sunset",
            "keywords": "city_sunrise"
        },
        {
            "glyph": "🌉",
            "name": "Bridge at night",
            "keywords": "bridge_at_night"
        },
        {
            "glyph": "♨️",
            "name": "Hot springs",
            "keywords": "hotsprings"
        },
        {
            "glyph": "🎠",
            "name": "Carousel horse",
            "keywords": "carousel_horse"
        },
        {
            "glyph": "🛝",
            "name": "Playground slide",
            "keywords": "playground_slide"
        },
        {
            "glyph": "🎡",
            "name": "Ferris wheel",
            "keywords": "ferris_wheel"
        },
        {
            "glyph": "🎢",
            "name": "Roller coaster",
            "keywords": "roller_coaster"
        },
        {
            "glyph": "💈",
            "name": "Barber pole",
            "keywords": "barber"
        },
        {
            "glyph": "🎪",
            "name": "Circus tent",
            "keywords": "circus_tent"
        },
        {
            "glyph": "🚂",
            "name": "Locomotive",
            "keywords": "steam_locomotive train"
        },
        {
            "glyph": "🚃",
            "name": "Railway car",
            "keywords": "railway_car"
        },
        {
            "glyph": "🚄",
            "name": "High-speed train",
            "keywords": "bullettrain_side train"
        },
        {
            "glyph": "🚅",
            "name": "Bullet train",
            "keywords": "bullettrain_front train"
        },
        {
            "glyph": "🚆",
            "name": "Train",
            "keywords": "train2"
        },
        {
            "glyph": "🚇",
            "name": "Metro",
            "keywords": "metro"
        },
        {
            "glyph": "🚈",
            "name": "Light rail",
            "keywords": "light_rail"
        },
        {
            "glyph": "🚉",
            "name": "Station",
            "keywords": "station"
        },
        {
            "glyph": "🚊",
            "name": "Tram",
            "keywords": "tram"
        },
        {
            "glyph": "🚝",
            "name": "Monorail",
            "keywords": "monorail"
        },
        {
            "glyph": "🚞",
            "name": "Mountain railway",
            "keywords": "mountain_railway"
        },
        {
            "glyph": "🚋",
            "name": "Tram car",
            "keywords": "train"
        },
        {
            "glyph": "🚌",
            "name": "Bus",
            "keywords": "bus"
        },
        {
            "glyph": "🚍",
            "name": "Oncoming bus",
            "keywords": "oncoming_bus"
        },
        {
            "glyph": "🚎",
            "name": "Trolleybus",
            "keywords": "trolleybus"
        },
        {
            "glyph": "🚐",
            "name": "Minibus",
            "keywords": "minibus"
        },
        {
            "glyph": "🚑",
            "name": "Ambulance",
            "keywords": "ambulance"
        },
        {
            "glyph": "🚒",
            "name": "Fire engine",
            "keywords": "fire_engine"
        },
        {
            "glyph": "🚓",
            "name": "Police car",
            "keywords": "police_car"
        },
        {
            "glyph": "🚔",
            "name": "Oncoming police car",
            "keywords": "oncoming_police_car"
        },
        {
            "glyph": "🚕",
            "name": "Taxi",
            "keywords": "taxi"
        },
        {
            "glyph": "🚖",
            "name": "Oncoming taxi",
            "keywords": "oncoming_taxi"
        },
        {
            "glyph": "🚗",
            "name": "Automobile",
            "keywords": "car red_car"
        },
        {
            "glyph": "🚘",
            "name": "Oncoming automobile",
            "keywords": "oncoming_automobile"
        },
        {
            "glyph": "🚙",
            "name": "Sport utility vehicle",
            "keywords": "blue_car"
        },
        {
            "glyph": "🛻",
            "name": "Pickup truck",
            "keywords": "pickup_truck"
        },
        {
            "glyph": "🚚",
            "name": "Delivery truck",
            "keywords": "truck"
        },
        {
            "glyph": "🚛",
            "name": "Articulated lorry",
            "keywords": "articulated_lorry"
        },
        {
            "glyph": "🚜",
            "name": "Tractor",
            "keywords": "tractor"
        },
        {
            "glyph": "🏎️",
            "name": "Racing car",
            "keywords": "racing_car"
        },
        {
            "glyph": "🏍️",
            "name": "Motorcycle",
            "keywords": "motorcycle"
        },
        {
            "glyph": "🛵",
            "name": "Motor scooter",
            "keywords": "motor_scooter"
        },
        {
            "glyph": "🦽",
            "name": "Manual wheelchair",
            "keywords": "manual_wheelchair"
        },
        {
            "glyph": "🦼",
            "name": "Motorized wheelchair",
            "keywords": "motorized_wheelchair"
        },
        {
            "glyph": "🛺",
            "name": "Auto rickshaw",
            "keywords": "auto_rickshaw"
        },
        {
            "glyph": "🚲",
            "name": "Bicycle",
            "keywords": "bike bicycle"
        },
        {
            "glyph": "🛴",
            "name": "Kick scooter",
            "keywords": "kick_scooter"
        },
        {
            "glyph": "🛹",
            "name": "Skateboard",
            "keywords": "skateboard"
        },
        {
            "glyph": "🛼",
            "name": "Roller skate",
            "keywords": "roller_skate"
        },
        {
            "glyph": "🚏",
            "name": "Bus stop",
            "keywords": "busstop"
        },
        {
            "glyph": "🛣️",
            "name": "Motorway",
            "keywords": "motorway"
        },
        {
            "glyph": "🛤️",
            "name": "Railway track",
            "keywords": "railway_track"
        },
        {
            "glyph": "🛢️",
            "name": "Oil drum",
            "keywords": "oil_drum"
        },
        {
            "glyph": "⛽",
            "name": "Fuel pump",
            "keywords": "fuelpump"
        },
        {
            "glyph": "🛞",
            "name": "Wheel",
            "keywords": "wheel"
        },
        {
            "glyph": "🚨",
            "name": "Police car light",
            "keywords": "rotating_light 911 emergency"
        },
        {
            "glyph": "🚥",
            "name": "Horizontal traffic light",
            "keywords": "traffic_light"
        },
        {
            "glyph": "🚦",
            "name": "Vertical traffic light",
            "keywords": "vertical_traffic_light semaphore"
        },
        {
            "glyph": "🛑",
            "name": "Stop sign",
            "keywords": "stop_sign"
        },
        {
            "glyph": "🚧",
            "name": "Construction",
            "keywords": "construction wip"
        },
        {
            "glyph": "⚓",
            "name": "Anchor",
            "keywords": "anchor ship"
        },
        {
            "glyph": "🛟",
            "name": "Ring buoy",
            "keywords": "ring_buoy life preserver"
        },
        {
            "glyph": "⛵",
            "name": "Sailboat",
            "keywords": "boat sailboat"
        },
        {
            "glyph": "🛶",
            "name": "Canoe",
            "keywords": "canoe"
        },
        {
            "glyph": "🚤",
            "name": "Speedboat",
            "keywords": "speedboat ship"
        },
        {
            "glyph": "🛳️",
            "name": "Passenger ship",
            "keywords": "passenger_ship cruise"
        },
        {
            "glyph": "⛴️",
            "name": "Ferry",
            "keywords": "ferry"
        },
        {
            "glyph": "🛥️",
            "name": "Motor boat",
            "keywords": "motor_boat"
        },
        {
            "glyph": "🚢",
            "name": "Ship",
            "keywords": "ship"
        },
        {
            "glyph": "✈️",
            "name": "Airplane",
            "keywords": "airplane flight"
        },
        {
            "glyph": "🛩️",
            "name": "Small airplane",
            "keywords": "small_airplane flight"
        },
        {
            "glyph": "🛫",
            "name": "Airplane departure",
            "keywords": "flight_departure"
        },
        {
            "glyph": "🛬",
            "name": "Airplane arrival",
            "keywords": "flight_arrival"
        },
        {
            "glyph": "🪂",
            "name": "Parachute",
            "keywords": "parachute"
        },
        {
            "glyph": "💺",
            "name": "Seat",
            "keywords": "seat"
        },
        {
            "glyph": "🚁",
            "name": "Helicopter",
            "keywords": "helicopter"
        },
        {
            "glyph": "🚟",
            "name": "Suspension railway",
            "keywords": "suspension_railway"
        },
        {
            "glyph": "🚠",
            "name": "Mountain cableway",
            "keywords": "mountain_cableway"
        },
        {
            "glyph": "🚡",
            "name": "Aerial tramway",
            "keywords": "aerial_tramway"
        },
        {
            "glyph": "🛰️",
            "name": "Satellite",
            "keywords": "artificial_satellite orbit space"
        },
        {
            "glyph": "🚀",
            "name": "Rocket",
            "keywords": "rocket ship launch"
        },
        {
            "glyph": "🛸",
            "name": "Flying saucer",
            "keywords": "flying_saucer ufo"
        },
        {
            "glyph": "🛎️",
            "name": "Bellhop bell",
            "keywords": "bellhop_bell"
        },
        {
            "glyph": "🧳",
            "name": "Luggage",
            "keywords": "luggage"
        },
        {
            "glyph": "⌛",
            "name": "Hourglass done",
            "keywords": "hourglass time"
        },
        {
            "glyph": "⏳",
            "name": "Hourglass not done",
            "keywords": "hourglass_flowing_sand time"
        },
        {
            "glyph": "⌚",
            "name": "Watch",
            "keywords": "watch time"
        },
        {
            "glyph": "⏰",
            "name": "Alarm clock",
            "keywords": "alarm_clock morning"
        },
        {
            "glyph": "⏱️",
            "name": "Stopwatch",
            "keywords": "stopwatch"
        },
        {
            "glyph": "⏲️",
            "name": "Timer clock",
            "keywords": "timer_clock"
        },
        {
            "glyph": "🕰️",
            "name": "Mantelpiece clock",
            "keywords": "mantelpiece_clock"
        },
        {
            "glyph": "🕛",
            "name": "Twelve o’clock",
            "keywords": "clock12"
        },
        {
            "glyph": "🕧",
            "name": "Twelve-thirty",
            "keywords": "clock1230"
        },
        {
            "glyph": "🕐",
            "name": "One o’clock",
            "keywords": "clock1"
        },
        {
            "glyph": "🕜",
            "name": "One-thirty",
            "keywords": "clock130"
        },
        {
            "glyph": "🕑",
            "name": "Two o’clock",
            "keywords": "clock2"
        },
        {
            "glyph": "🕝",
            "name": "Two-thirty",
            "keywords": "clock230"
        },
        {
            "glyph": "🕒",
            "name": "Three o’clock",
            "keywords": "clock3"
        },
        {
            "glyph": "🕞",
            "name": "Three-thirty",
            "keywords": "clock330"
        },
        {
            "glyph": "🕓",
            "name": "Four o’clock",
            "keywords": "clock4"
        },
        {
            "glyph": "🕟",
            "name": "Four-thirty",
            "keywords": "clock430"
        },
        {
            "glyph": "🕔",
            "name": "Five o’clock",
            "keywords": "clock5"
        },
        {
            "glyph": "🕠",
            "name": "Five-thirty",
            "keywords": "clock530"
        },
        {
            "glyph": "🕕",
            "name": "Six o’clock",
            "keywords": "clock6"
        },
        {
            "glyph": "🕡",
            "name": "Six-thirty",
            "keywords": "clock630"
        },
        {
            "glyph": "🕖",
            "name": "Seven o’clock",
            "keywords": "clock7"
        },
        {
            "glyph": "🕢",
            "name": "Seven-thirty",
            "keywords": "clock730"
        },
        {
            "glyph": "🕗",
            "name": "Eight o’clock",
            "keywords": "clock8"
        },
        {
            "glyph": "🕣",
            "name": "Eight-thirty",
            "keywords": "clock830"
        },
        {
            "glyph": "🕘",
            "name": "Nine o’clock",
            "keywords": "clock9"
        },
        {
            "glyph": "🕤",
            "name": "Nine-thirty",
            "keywords": "clock930"
        },
        {
            "glyph": "🕙",
            "name": "Ten o’clock",
            "keywords": "clock10"
        },
        {
            "glyph": "🕥",
            "name": "Ten-thirty",
            "keywords": "clock1030"
        },
        {
            "glyph": "🕚",
            "name": "Eleven o’clock",
            "keywords": "clock11"
        },
        {
            "glyph": "🕦",
            "name": "Eleven-thirty",
            "keywords": "clock1130"
        },
        {
            "glyph": "🌑",
            "name": "New moon",
            "keywords": "new_moon"
        },
        {
            "glyph": "🌒",
            "name": "Waxing crescent moon",
            "keywords": "waxing_crescent_moon"
        },
        {
            "glyph": "🌓",
            "name": "First quarter moon",
            "keywords": "first_quarter_moon"
        },
        {
            "glyph": "🌔",
            "name": "Waxing gibbous moon",
            "keywords": "moon waxing_gibbous_moon"
        },
        {
            "glyph": "🌕",
            "name": "Full moon",
            "keywords": "full_moon"
        },
        {
            "glyph": "🌖",
            "name": "Waning gibbous moon",
            "keywords": "waning_gibbous_moon"
        },
        {
            "glyph": "🌗",
            "name": "Last quarter moon",
            "keywords": "last_quarter_moon"
        },
        {
            "glyph": "🌘",
            "name": "Waning crescent moon",
            "keywords": "waning_crescent_moon"
        },
        {
            "glyph": "🌙",
            "name": "Crescent moon",
            "keywords": "crescent_moon night"
        },
        {
            "glyph": "🌚",
            "name": "New moon face",
            "keywords": "new_moon_with_face"
        },
        {
            "glyph": "🌛",
            "name": "First quarter moon face",
            "keywords": "first_quarter_moon_with_face"
        },
        {
            "glyph": "🌜",
            "name": "Last quarter moon face",
            "keywords": "last_quarter_moon_with_face"
        },
        {
            "glyph": "🌡️",
            "name": "Thermometer",
            "keywords": "thermometer"
        },
        {
            "glyph": "☀️",
            "name": "Sun",
            "keywords": "sunny weather"
        },
        {
            "glyph": "🌝",
            "name": "Full moon face",
            "keywords": "full_moon_with_face"
        },
        {
            "glyph": "🌞",
            "name": "Sun with face",
            "keywords": "sun_with_face summer"
        },
        {
            "glyph": "🪐",
            "name": "Ringed planet",
            "keywords": "ringed_planet"
        },
        {
            "glyph": "⭐",
            "name": "Star",
            "keywords": "star"
        },
        {
            "glyph": "🌟",
            "name": "Glowing star",
            "keywords": "star2"
        },
        {
            "glyph": "🌠",
            "name": "Shooting star",
            "keywords": "stars"
        },
        {
            "glyph": "🌌",
            "name": "Milky way",
            "keywords": "milky_way"
        },
        {
            "glyph": "☁️",
            "name": "Cloud",
            "keywords": "cloud"
        },
        {
            "glyph": "⛅",
            "name": "Sun behind cloud",
            "keywords": "partly_sunny weather cloud"
        },
        {
            "glyph": "⛈️",
            "name": "Cloud with lightning and rain",
            "keywords": "cloud_with_lightning_and_rain"
        },
        {
            "glyph": "🌤️",
            "name": "Sun behind small cloud",
            "keywords": "sun_behind_small_cloud"
        },
        {
            "glyph": "🌥️",
            "name": "Sun behind large cloud",
            "keywords": "sun_behind_large_cloud"
        },
        {
            "glyph": "🌦️",
            "name": "Sun behind rain cloud",
            "keywords": "sun_behind_rain_cloud"
        },
        {
            "glyph": "🌧️",
            "name": "Cloud with rain",
            "keywords": "cloud_with_rain"
        },
        {
            "glyph": "🌨️",
            "name": "Cloud with snow",
            "keywords": "cloud_with_snow"
        },
        {
            "glyph": "🌩️",
            "name": "Cloud with lightning",
            "keywords": "cloud_with_lightning"
        },
        {
            "glyph": "🌪️",
            "name": "Tornado",
            "keywords": "tornado"
        },
        {
            "glyph": "🌫️",
            "name": "Fog",
            "keywords": "fog"
        },
        {
            "glyph": "🌬️",
            "name": "Wind face",
            "keywords": "wind_face"
        },
        {
            "glyph": "🌀",
            "name": "Cyclone",
            "keywords": "cyclone swirl"
        },
        {
            "glyph": "🌈",
            "name": "Rainbow",
            "keywords": "rainbow"
        },
        {
            "glyph": "🌂",
            "name": "Closed umbrella",
            "keywords": "closed_umbrella weather rain"
        },
        {
            "glyph": "☂️",
            "name": "Umbrella",
            "keywords": "open_umbrella"
        },
        {
            "glyph": "☔",
            "name": "Umbrella with rain drops",
            "keywords": "umbrella rain weather"
        },
        {
            "glyph": "⛱️",
            "name": "Umbrella on ground",
            "keywords": "parasol_on_ground beach_umbrella"
        },
        {
            "glyph": "⚡",
            "name": "High voltage",
            "keywords": "zap lightning thunder"
        },
        {
            "glyph": "❄️",
            "name": "Snowflake",
            "keywords": "snowflake winter cold weather"
        },
        {
            "glyph": "☃️",
            "name": "Snowman",
            "keywords": "snowman_with_snow winter christmas"
        },
        {
            "glyph": "⛄",
            "name": "Snowman without snow",
            "keywords": "snowman winter"
        },
        {
            "glyph": "☄️",
            "name": "Comet",
            "keywords": "comet"
        },
        {
            "glyph": "🔥",
            "name": "Fire",
            "keywords": "fire burn"
        },
        {
            "glyph": "💧",
            "name": "Droplet",
            "keywords": "droplet water"
        },
        {
            "glyph": "🌊",
            "name": "Water wave",
            "keywords": "ocean sea"
        },
        {
            "glyph": "🎃",
            "name": "Jack-o-lantern",
            "keywords": "jack_o_lantern halloween"
        },
        {
            "glyph": "🎄",
            "name": "Christmas tree",
            "keywords": "christmas_tree"
        },
        {
            "glyph": "🎆",
            "name": "Fireworks",
            "keywords": "fireworks festival celebration"
        },
        {
            "glyph": "🎇",
            "name": "Sparkler",
            "keywords": "sparkler"
        },
        {
            "glyph": "🧨",
            "name": "Firecracker",
            "keywords": "firecracker"
        },
        {
            "glyph": "✨",
            "name": "Sparkles",
            "keywords": "sparkles shiny"
        },
        {
            "glyph": "🎈",
            "name": "Balloon",
            "keywords": "balloon party birthday"
        },
        {
            "glyph": "🎉",
            "name": "Party popper",
            "keywords": "tada hooray party"
        },
        {
            "glyph": "🎊",
            "name": "Confetti ball",
            "keywords": "confetti_ball"
        },
        {
            "glyph": "🎋",
            "name": "Tanabata tree",
            "keywords": "tanabata_tree"
        },
        {
            "glyph": "🎍",
            "name": "Pine decoration",
            "keywords": "bamboo"
        },
        {
            "glyph": "🎎",
            "name": "Japanese dolls",
            "keywords": "dolls"
        },
        {
            "glyph": "🎏",
            "name": "Carp streamer",
            "keywords": "flags"
        },
        {
            "glyph": "🎐",
            "name": "Wind chime",
            "keywords": "wind_chime"
        },
        {
            "glyph": "🎑",
            "name": "Moon viewing ceremony",
            "keywords": "rice_scene"
        },
        {
            "glyph": "🧧",
            "name": "Red envelope",
            "keywords": "red_envelope"
        },
        {
            "glyph": "🎀",
            "name": "Ribbon",
            "keywords": "ribbon"
        },
        {
            "glyph": "🎁",
            "name": "Wrapped gift",
            "keywords": "gift present birthday christmas"
        },
        {
            "glyph": "🎗️",
            "name": "Reminder ribbon",
            "keywords": "reminder_ribbon"
        },
        {
            "glyph": "🎟️",
            "name": "Admission tickets",
            "keywords": "tickets"
        },
        {
            "glyph": "🎫",
            "name": "Ticket",
            "keywords": "ticket"
        },
        {
            "glyph": "🎖️",
            "name": "Military medal",
            "keywords": "medal_military"
        },
        {
            "glyph": "🏆",
            "name": "Trophy",
            "keywords": "trophy award contest winner"
        },
        {
            "glyph": "🏅",
            "name": "Sports medal",
            "keywords": "medal_sports gold winner"
        },
        {
            "glyph": "🥇",
            "name": "1st place medal",
            "keywords": "1st_place_medal gold"
        },
        {
            "glyph": "🥈",
            "name": "2nd place medal",
            "keywords": "2nd_place_medal silver"
        },
        {
            "glyph": "🥉",
            "name": "3rd place medal",
            "keywords": "3rd_place_medal bronze"
        },
        {
            "glyph": "⚽",
            "name": "Soccer ball",
            "keywords": "soccer sports"
        },
        {
            "glyph": "⚾",
            "name": "Baseball",
            "keywords": "baseball sports"
        },
        {
            "glyph": "🥎",
            "name": "Softball",
            "keywords": "softball"
        },
        {
            "glyph": "🏀",
            "name": "Basketball",
            "keywords": "basketball sports"
        },
        {
            "glyph": "🏐",
            "name": "Volleyball",
            "keywords": "volleyball"
        },
        {
            "glyph": "🏈",
            "name": "American football",
            "keywords": "football sports"
        },
        {
            "glyph": "🏉",
            "name": "Rugby football",
            "keywords": "rugby_football"
        },
        {
            "glyph": "🎾",
            "name": "Tennis",
            "keywords": "tennis sports"
        },
        {
            "glyph": "🥏",
            "name": "Flying disc",
            "keywords": "flying_disc"
        },
        {
            "glyph": "🎳",
            "name": "Bowling",
            "keywords": "bowling"
        },
        {
            "glyph": "🏏",
            "name": "Cricket game",
            "keywords": "cricket_game"
        },
        {
            "glyph": "🏑",
            "name": "Field hockey",
            "keywords": "field_hockey"
        },
        {
            "glyph": "🏒",
            "name": "Ice hockey",
            "keywords": "ice_hockey"
        },
        {
            "glyph": "🥍",
            "name": "Lacrosse",
            "keywords": "lacrosse"
        },
        {
            "glyph": "🏓",
            "name": "Ping pong",
            "keywords": "ping_pong"
        },
        {
            "glyph": "🏸",
            "name": "Badminton",
            "keywords": "badminton"
        },
        {
            "glyph": "🥊",
            "name": "Boxing glove",
            "keywords": "boxing_glove"
        },
        {
            "glyph": "🥋",
            "name": "Martial arts uniform",
            "keywords": "martial_arts_uniform"
        },
        {
            "glyph": "🥅",
            "name": "Goal net",
            "keywords": "goal_net"
        },
        {
            "glyph": "⛳",
            "name": "Flag in hole",
            "keywords": "golf"
        },
        {
            "glyph": "⛸️",
            "name": "Ice skate",
            "keywords": "ice_skate skating"
        },
        {
            "glyph": "🎣",
            "name": "Fishing pole",
            "keywords": "fishing_pole_and_fish"
        },
        {
            "glyph": "🤿",
            "name": "Diving mask",
            "keywords": "diving_mask"
        },
        {
            "glyph": "🎽",
            "name": "Running shirt",
            "keywords": "running_shirt_with_sash marathon"
        },
        {
            "glyph": "🎿",
            "name": "Skis",
            "keywords": "ski"
        },
        {
            "glyph": "🛷",
            "name": "Sled",
            "keywords": "sled"
        },
        {
            "glyph": "🥌",
            "name": "Curling stone",
            "keywords": "curling_stone"
        },
        {
            "glyph": "🎯",
            "name": "Bullseye",
            "keywords": "dart target"
        },
        {
            "glyph": "🪀",
            "name": "Yo-yo",
            "keywords": "yo_yo"
        },
        {
            "glyph": "🪁",
            "name": "Kite",
            "keywords": "kite"
        },
        {
            "glyph": "🔫",
            "name": "Water pistol",
            "keywords": "gun shoot weapon"
        },
        {
            "glyph": "🎱",
            "name": "Pool 8 ball",
            "keywords": "8ball pool billiards"
        },
        {
            "glyph": "🔮",
            "name": "Crystal ball",
            "keywords": "crystal_ball fortune"
        },
        {
            "glyph": "🪄",
            "name": "Magic wand",
            "keywords": "magic_wand"
        },
        {
            "glyph": "🎮",
            "name": "Video game",
            "keywords": "video_game play controller console"
        },
        {
            "glyph": "🕹️",
            "name": "Joystick",
            "keywords": "joystick"
        },
        {
            "glyph": "🎰",
            "name": "Slot machine",
            "keywords": "slot_machine"
        },
        {
            "glyph": "🎲",
            "name": "Game die",
            "keywords": "game_die dice gambling"
        },
        {
            "glyph": "🧩",
            "name": "Puzzle piece",
            "keywords": "jigsaw"
        },
        {
            "glyph": "🧸",
            "name": "Teddy bear",
            "keywords": "teddy_bear"
        },
        {
            "glyph": "🪅",
            "name": "Piñata",
            "keywords": "pinata"
        },
        {
            "glyph": "🪩",
            "name": "Mirror ball",
            "keywords": "mirror_ball disco party"
        },
        {
            "glyph": "🪆",
            "name": "Nesting dolls",
            "keywords": "nesting_dolls"
        },
        {
            "glyph": "♠️",
            "name": "Spade suit",
            "keywords": "spades"
        },
        {
            "glyph": "♥️",
            "name": "Heart suit",
            "keywords": "hearts"
        },
        {
            "glyph": "♦️",
            "name": "Diamond suit",
            "keywords": "diamonds"
        },
        {
            "glyph": "♣️",
            "name": "Club suit",
            "keywords": "clubs"
        },
        {
            "glyph": "♟️",
            "name": "Chess pawn",
            "keywords": "chess_pawn"
        },
        {
            "glyph": "🃏",
            "name": "Joker",
            "keywords": "black_joker"
        },
        {
            "glyph": "🀄",
            "name": "Mahjong red dragon",
            "keywords": "mahjong"
        },
        {
            "glyph": "🎴",
            "name": "Flower playing cards",
            "keywords": "flower_playing_cards"
        },
        {
            "glyph": "🎭",
            "name": "Performing arts",
            "keywords": "performing_arts theater drama"
        },
        {
            "glyph": "🖼️",
            "name": "Framed picture",
            "keywords": "framed_picture"
        },
        {
            "glyph": "🎨",
            "name": "Artist palette",
            "keywords": "art design paint"
        },
        {
            "glyph": "🧵",
            "name": "Thread",
            "keywords": "thread"
        },
        {
            "glyph": "🪡",
            "name": "Sewing needle",
            "keywords": "sewing_needle"
        },
        {
            "glyph": "🧶",
            "name": "Yarn",
            "keywords": "yarn"
        },
        {
            "glyph": "🪢",
            "name": "Knot",
            "keywords": "knot"
        },
        {
            "glyph": "👓",
            "name": "Glasses",
            "keywords": "eyeglasses glasses"
        },
        {
            "glyph": "🕶️",
            "name": "Sunglasses",
            "keywords": "dark_sunglasses"
        },
        {
            "glyph": "🥽",
            "name": "Goggles",
            "keywords": "goggles"
        },
        {
            "glyph": "🥼",
            "name": "Lab coat",
            "keywords": "lab_coat"
        },
        {
            "glyph": "🦺",
            "name": "Safety vest",
            "keywords": "safety_vest"
        },
        {
            "glyph": "👔",
            "name": "Necktie",
            "keywords": "necktie shirt formal"
        },
        {
            "glyph": "👕",
            "name": "T-shirt",
            "keywords": "shirt tshirt"
        },
        {
            "glyph": "👖",
            "name": "Jeans",
            "keywords": "jeans pants"
        },
        {
            "glyph": "🧣",
            "name": "Scarf",
            "keywords": "scarf"
        },
        {
            "glyph": "🧤",
            "name": "Gloves",
            "keywords": "gloves"
        },
        {
            "glyph": "🧥",
            "name": "Coat",
            "keywords": "coat"
        },
        {
            "glyph": "🧦",
            "name": "Socks",
            "keywords": "socks"
        },
        {
            "glyph": "👗",
            "name": "Dress",
            "keywords": "dress"
        },
        {
            "glyph": "👘",
            "name": "Kimono",
            "keywords": "kimono"
        },
        {
            "glyph": "🥻",
            "name": "Sari",
            "keywords": "sari"
        },
        {
            "glyph": "🩱",
            "name": "One-piece swimsuit",
            "keywords": "one_piece_swimsuit"
        },
        {
            "glyph": "🩲",
            "name": "Briefs",
            "keywords": "swim_brief"
        },
        {
            "glyph": "🩳",
            "name": "Shorts",
            "keywords": "shorts"
        },
        {
            "glyph": "👙",
            "name": "Bikini",
            "keywords": "bikini beach"
        },
        {
            "glyph": "👚",
            "name": "Woman’s clothes",
            "keywords": "womans_clothes"
        },
        {
            "glyph": "🪭",
            "name": "Folding hand fan",
            "keywords": "folding_hand_fan sensu"
        },
        {
            "glyph": "👛",
            "name": "Purse",
            "keywords": "purse"
        },
        {
            "glyph": "👜",
            "name": "Handbag",
            "keywords": "handbag bag"
        },
        {
            "glyph": "👝",
            "name": "Clutch bag",
            "keywords": "pouch bag"
        },
        {
            "glyph": "🛍️",
            "name": "Shopping bags",
            "keywords": "shopping bags"
        },
        {
            "glyph": "🎒",
            "name": "Backpack",
            "keywords": "school_satchel"
        },
        {
            "glyph": "🩴",
            "name": "Thong sandal",
            "keywords": "thong_sandal"
        },
        {
            "glyph": "👞",
            "name": "Man’s shoe",
            "keywords": "mans_shoe shoe"
        },
        {
            "glyph": "👟",
            "name": "Running shoe",
            "keywords": "athletic_shoe sneaker sport running"
        },
        {
            "glyph": "🥾",
            "name": "Hiking boot",
            "keywords": "hiking_boot"
        },
        {
            "glyph": "🥿",
            "name": "Flat shoe",
            "keywords": "flat_shoe"
        },
        {
            "glyph": "👠",
            "name": "High-heeled shoe",
            "keywords": "high_heel shoe"
        },
        {
            "glyph": "👡",
            "name": "Woman’s sandal",
            "keywords": "sandal shoe"
        },
        {
            "glyph": "🩰",
            "name": "Ballet shoes",
            "keywords": "ballet_shoes"
        },
        {
            "glyph": "👢",
            "name": "Woman’s boot",
            "keywords": "boot"
        },
        {
            "glyph": "🪮",
            "name": "Hair pick",
            "keywords": "hair_pick"
        },
        {
            "glyph": "👑",
            "name": "Crown",
            "keywords": "crown king queen royal"
        },
        {
            "glyph": "👒",
            "name": "Woman’s hat",
            "keywords": "womans_hat"
        },
        {
            "glyph": "🎩",
            "name": "Top hat",
            "keywords": "tophat hat classy"
        },
        {
            "glyph": "🎓",
            "name": "Graduation cap",
            "keywords": "mortar_board education college university graduation"
        },
        {
            "glyph": "🧢",
            "name": "Billed cap",
            "keywords": "billed_cap"
        },
        {
            "glyph": "🪖",
            "name": "Military helmet",
            "keywords": "military_helmet"
        },
        {
            "glyph": "⛑️",
            "name": "Rescue worker’s helmet",
            "keywords": "rescue_worker_helmet"
        },
        {
            "glyph": "📿",
            "name": "Prayer beads",
            "keywords": "prayer_beads"
        },
        {
            "glyph": "💄",
            "name": "Lipstick",
            "keywords": "lipstick makeup"
        },
        {
            "glyph": "💍",
            "name": "Ring",
            "keywords": "ring wedding marriage engaged"
        },
        {
            "glyph": "💎",
            "name": "Gem stone",
            "keywords": "gem diamond"
        },
        {
            "glyph": "🔇",
            "name": "Muted speaker",
            "keywords": "mute sound volume"
        },
        {
            "glyph": "🔈",
            "name": "Speaker low volume",
            "keywords": "speaker"
        },
        {
            "glyph": "🔉",
            "name": "Speaker medium volume",
            "keywords": "sound volume"
        },
        {
            "glyph": "🔊",
            "name": "Speaker high volume",
            "keywords": "loud_sound volume"
        },
        {
            "glyph": "📢",
            "name": "Loudspeaker",
            "keywords": "loudspeaker announcement"
        },
        {
            "glyph": "📣",
            "name": "Megaphone",
            "keywords": "mega"
        },
        {
            "glyph": "📯",
            "name": "Postal horn",
            "keywords": "postal_horn"
        },
        {
            "glyph": "🔔",
            "name": "Bell",
            "keywords": "bell sound notification"
        },
        {
            "glyph": "🔕",
            "name": "Bell with slash",
            "keywords": "no_bell volume off"
        },
        {
            "glyph": "🎼",
            "name": "Musical score",
            "keywords": "musical_score"
        },
        {
            "glyph": "🎵",
            "name": "Musical note",
            "keywords": "musical_note"
        },
        {
            "glyph": "🎶",
            "name": "Musical notes",
            "keywords": "notes music"
        },
        {
            "glyph": "🎙️",
            "name": "Studio microphone",
            "keywords": "studio_microphone podcast"
        },
        {
            "glyph": "🎚️",
            "name": "Level slider",
            "keywords": "level_slider"
        },
        {
            "glyph": "🎛️",
            "name": "Control knobs",
            "keywords": "control_knobs"
        },
        {
            "glyph": "🎤",
            "name": "Microphone",
            "keywords": "microphone sing"
        },
        {
            "glyph": "🎧",
            "name": "Headphone",
            "keywords": "headphones music earphones"
        },
        {
            "glyph": "📻",
            "name": "Radio",
            "keywords": "radio podcast"
        },
        {
            "glyph": "🎷",
            "name": "Saxophone",
            "keywords": "saxophone"
        },
        {
            "glyph": "🪗",
            "name": "Accordion",
            "keywords": "accordion"
        },
        {
            "glyph": "🎸",
            "name": "Guitar",
            "keywords": "guitar rock"
        },
        {
            "glyph": "🎹",
            "name": "Musical keyboard",
            "keywords": "musical_keyboard piano"
        },
        {
            "glyph": "🎺",
            "name": "Trumpet",
            "keywords": "trumpet"
        },
        {
            "glyph": "🎻",
            "name": "Violin",
            "keywords": "violin"
        },
        {
            "glyph": "🪕",
            "name": "Banjo",
            "keywords": "banjo"
        },
        {
            "glyph": "🥁",
            "name": "Drum",
            "keywords": "drum"
        },
        {
            "glyph": "🪘",
            "name": "Long drum",
            "keywords": "long_drum"
        },
        {
            "glyph": "🪇",
            "name": "Maracas",
            "keywords": "maracas shaker"
        },
        {
            "glyph": "🪈",
            "name": "Flute",
            "keywords": "flute recorder"
        },
        {
            "glyph": "📱",
            "name": "Mobile phone",
            "keywords": "iphone smartphone mobile"
        },
        {
            "glyph": "📲",
            "name": "Mobile phone with arrow",
            "keywords": "calling call incoming"
        },
        {
            "glyph": "☎️",
            "name": "Telephone",
            "keywords": "phone telephone"
        },
        {
            "glyph": "📞",
            "name": "Telephone receiver",
            "keywords": "telephone_receiver phone call"
        },
        {
            "glyph": "📟",
            "name": "Pager",
            "keywords": "pager"
        },
        {
            "glyph": "📠",
            "name": "Fax machine",
            "keywords": "fax"
        },
        {
            "glyph": "🔋",
            "name": "Battery",
            "keywords": "battery power"
        },
        {
            "glyph": "🪫",
            "name": "Low battery",
            "keywords": "low_battery"
        },
        {
            "glyph": "🔌",
            "name": "Electric plug",
            "keywords": "electric_plug"
        },
        {
            "glyph": "💻",
            "name": "Laptop",
            "keywords": "computer desktop screen"
        },
        {
            "glyph": "🖥️",
            "name": "Desktop computer",
            "keywords": "desktop_computer"
        },
        {
            "glyph": "🖨️",
            "name": "Printer",
            "keywords": "printer"
        },
        {
            "glyph": "⌨️",
            "name": "Keyboard",
            "keywords": "keyboard"
        },
        {
            "glyph": "🖱️",
            "name": "Computer mouse",
            "keywords": "computer_mouse"
        },
        {
            "glyph": "🖲️",
            "name": "Trackball",
            "keywords": "trackball"
        },
        {
            "glyph": "💽",
            "name": "Computer disk",
            "keywords": "minidisc"
        },
        {
            "glyph": "💾",
            "name": "Floppy disk",
            "keywords": "floppy_disk save"
        },
        {
            "glyph": "💿",
            "name": "Optical disk",
            "keywords": "cd"
        },
        {
            "glyph": "📀",
            "name": "Dvd",
            "keywords": "dvd"
        },
        {
            "glyph": "🧮",
            "name": "Abacus",
            "keywords": "abacus"
        },
        {
            "glyph": "🎥",
            "name": "Movie camera",
            "keywords": "movie_camera film video"
        },
        {
            "glyph": "🎞️",
            "name": "Film frames",
            "keywords": "film_strip"
        },
        {
            "glyph": "📽️",
            "name": "Film projector",
            "keywords": "film_projector"
        },
        {
            "glyph": "🎬",
            "name": "Clapper board",
            "keywords": "clapper film"
        },
        {
            "glyph": "📺",
            "name": "Television",
            "keywords": "tv"
        },
        {
            "glyph": "📷",
            "name": "Camera",
            "keywords": "camera photo"
        },
        {
            "glyph": "📸",
            "name": "Camera with flash",
            "keywords": "camera_flash photo"
        },
        {
            "glyph": "📹",
            "name": "Video camera",
            "keywords": "video_camera"
        },
        {
            "glyph": "📼",
            "name": "Videocassette",
            "keywords": "vhs"
        },
        {
            "glyph": "🔍",
            "name": "Magnifying glass tilted left",
            "keywords": "mag search zoom"
        },
        {
            "glyph": "🔎",
            "name": "Magnifying glass tilted right",
            "keywords": "mag_right"
        },
        {
            "glyph": "🕯️",
            "name": "Candle",
            "keywords": "candle"
        },
        {
            "glyph": "💡",
            "name": "Light bulb",
            "keywords": "bulb idea light"
        },
        {
            "glyph": "🔦",
            "name": "Flashlight",
            "keywords": "flashlight"
        },
        {
            "glyph": "🏮",
            "name": "Red paper lantern",
            "keywords": "izakaya_lantern lantern"
        },
        {
            "glyph": "🪔",
            "name": "Diya lamp",
            "keywords": "diya_lamp"
        },
        {
            "glyph": "📔",
            "name": "Notebook with decorative cover",
            "keywords": "notebook_with_decorative_cover"
        },
        {
            "glyph": "📕",
            "name": "Closed book",
            "keywords": "closed_book"
        },
        {
            "glyph": "📖",
            "name": "Open book",
            "keywords": "book open_book"
        },
        {
            "glyph": "📗",
            "name": "Green book",
            "keywords": "green_book"
        },
        {
            "glyph": "📘",
            "name": "Blue book",
            "keywords": "blue_book"
        },
        {
            "glyph": "📙",
            "name": "Orange book",
            "keywords": "orange_book"
        },
        {
            "glyph": "📚",
            "name": "Books",
            "keywords": "books library"
        },
        {
            "glyph": "📓",
            "name": "Notebook",
            "keywords": "notebook"
        },
        {
            "glyph": "📒",
            "name": "Ledger",
            "keywords": "ledger"
        },
        {
            "glyph": "📃",
            "name": "Page with curl",
            "keywords": "page_with_curl"
        },
        {
            "glyph": "📜",
            "name": "Scroll",
            "keywords": "scroll document"
        },
        {
            "glyph": "📄",
            "name": "Page facing up",
            "keywords": "page_facing_up document"
        },
        {
            "glyph": "📰",
            "name": "Newspaper",
            "keywords": "newspaper press"
        },
        {
            "glyph": "🗞️",
            "name": "Rolled-up newspaper",
            "keywords": "newspaper_roll press"
        },
        {
            "glyph": "📑",
            "name": "Bookmark tabs",
            "keywords": "bookmark_tabs"
        },
        {
            "glyph": "🔖",
            "name": "Bookmark",
            "keywords": "bookmark"
        },
        {
            "glyph": "🏷️",
            "name": "Label",
            "keywords": "label tag"
        },
        {
            "glyph": "💰",
            "name": "Money bag",
            "keywords": "moneybag dollar cream"
        },
        {
            "glyph": "🪙",
            "name": "Coin",
            "keywords": "coin"
        },
        {
            "glyph": "💴",
            "name": "Yen banknote",
            "keywords": "yen"
        },
        {
            "glyph": "💵",
            "name": "Dollar banknote",
            "keywords": "dollar money"
        },
        {
            "glyph": "💶",
            "name": "Euro banknote",
            "keywords": "euro"
        },
        {
            "glyph": "💷",
            "name": "Pound banknote",
            "keywords": "pound"
        },
        {
            "glyph": "💸",
            "name": "Money with wings",
            "keywords": "money_with_wings dollar"
        },
        {
            "glyph": "💳",
            "name": "Credit card",
            "keywords": "credit_card subscription"
        },
        {
            "glyph": "🧾",
            "name": "Receipt",
            "keywords": "receipt"
        },
        {
            "glyph": "💹",
            "name": "Chart increasing with yen",
            "keywords": "chart"
        },
        {
            "glyph": "✉️",
            "name": "Envelope",
            "keywords": "envelope letter email"
        },
        {
            "glyph": "📧",
            "name": "E-mail",
            "keywords": "email e-mail"
        },
        {
            "glyph": "📨",
            "name": "Incoming envelope",
            "keywords": "incoming_envelope"
        },
        {
            "glyph": "📩",
            "name": "Envelope with arrow",
            "keywords": "envelope_with_arrow"
        },
        {
            "glyph": "📤",
            "name": "Outbox tray",
            "keywords": "outbox_tray"
        },
        {
            "glyph": "📥",
            "name": "Inbox tray",
            "keywords": "inbox_tray"
        },
        {
            "glyph": "📦",
            "name": "Package",
            "keywords": "package shipping"
        },
        {
            "glyph": "📫",
            "name": "Closed mailbox with raised flag",
            "keywords": "mailbox"
        },
        {
            "glyph": "📪",
            "name": "Closed mailbox with lowered flag",
            "keywords": "mailbox_closed"
        },
        {
            "glyph": "📬",
            "name": "Open mailbox with raised flag",
            "keywords": "mailbox_with_mail"
        },
        {
            "glyph": "📭",
            "name": "Open mailbox with lowered flag",
            "keywords": "mailbox_with_no_mail"
        },
        {
            "glyph": "📮",
            "name": "Postbox",
            "keywords": "postbox"
        },
        {
            "glyph": "🗳️",
            "name": "Ballot box with ballot",
            "keywords": "ballot_box"
        },
        {
            "glyph": "✏️",
            "name": "Pencil",
            "keywords": "pencil2"
        },
        {
            "glyph": "✒️",
            "name": "Black nib",
            "keywords": "black_nib"
        },
        {
            "glyph": "🖋️",
            "name": "Fountain pen",
            "keywords": "fountain_pen"
        },
        {
            "glyph": "🖊️",
            "name": "Pen",
            "keywords": "pen"
        },
        {
            "glyph": "🖌️",
            "name": "Paintbrush",
            "keywords": "paintbrush"
        },
        {
            "glyph": "🖍️",
            "name": "Crayon",
            "keywords": "crayon"
        },
        {
            "glyph": "📝",
            "name": "Memo",
            "keywords": "memo pencil document note"
        },
        {
            "glyph": "💼",
            "name": "Briefcase",
            "keywords": "briefcase business"
        },
        {
            "glyph": "📁",
            "name": "File folder",
            "keywords": "file_folder directory"
        },
        {
            "glyph": "📂",
            "name": "Open file folder",
            "keywords": "open_file_folder"
        },
        {
            "glyph": "🗂️",
            "name": "Card index dividers",
            "keywords": "card_index_dividers"
        },
        {
            "glyph": "📅",
            "name": "Calendar",
            "keywords": "date calendar schedule"
        },
        {
            "glyph": "📆",
            "name": "Tear-off calendar",
            "keywords": "calendar schedule"
        },
        {
            "glyph": "🗒️",
            "name": "Spiral notepad",
            "keywords": "spiral_notepad"
        },
        {
            "glyph": "🗓️",
            "name": "Spiral calendar",
            "keywords": "spiral_calendar"
        },
        {
            "glyph": "📇",
            "name": "Card index",
            "keywords": "card_index"
        },
        {
            "glyph": "📈",
            "name": "Chart increasing",
            "keywords": "chart_with_upwards_trend graph metrics"
        },
        {
            "glyph": "📉",
            "name": "Chart decreasing",
            "keywords": "chart_with_downwards_trend graph metrics"
        },
        {
            "glyph": "📊",
            "name": "Bar chart",
            "keywords": "bar_chart stats metrics"
        },
        {
            "glyph": "📋",
            "name": "Clipboard",
            "keywords": "clipboard"
        },
        {
            "glyph": "📌",
            "name": "Pushpin",
            "keywords": "pushpin location"
        },
        {
            "glyph": "📍",
            "name": "Round pushpin",
            "keywords": "round_pushpin location"
        },
        {
            "glyph": "📎",
            "name": "Paperclip",
            "keywords": "paperclip"
        },
        {
            "glyph": "🖇️",
            "name": "Linked paperclips",
            "keywords": "paperclips"
        },
        {
            "glyph": "📏",
            "name": "Straight ruler",
            "keywords": "straight_ruler"
        },
        {
            "glyph": "📐",
            "name": "Triangular ruler",
            "keywords": "triangular_ruler"
        },
        {
            "glyph": "✂️",
            "name": "Scissors",
            "keywords": "scissors cut"
        },
        {
            "glyph": "🗃️",
            "name": "Card file box",
            "keywords": "card_file_box"
        },
        {
            "glyph": "🗄️",
            "name": "File cabinet",
            "keywords": "file_cabinet"
        },
        {
            "glyph": "🗑️",
            "name": "Wastebasket",
            "keywords": "wastebasket trash"
        },
        {
            "glyph": "🔒",
            "name": "Locked",
            "keywords": "lock security private"
        },
        {
            "glyph": "🔓",
            "name": "Unlocked",
            "keywords": "unlock security"
        },
        {
            "glyph": "🔏",
            "name": "Locked with pen",
            "keywords": "lock_with_ink_pen"
        },
        {
            "glyph": "🔐",
            "name": "Locked with key",
            "keywords": "closed_lock_with_key security"
        },
        {
            "glyph": "🔑",
            "name": "Key",
            "keywords": "key lock password"
        },
        {
            "glyph": "🗝️",
            "name": "Old key",
            "keywords": "old_key"
        },
        {
            "glyph": "🔨",
            "name": "Hammer",
            "keywords": "hammer tool"
        },
        {
            "glyph": "🪓",
            "name": "Axe",
            "keywords": "axe"
        },
        {
            "glyph": "⛏️",
            "name": "Pick",
            "keywords": "pick"
        },
        {
            "glyph": "⚒️",
            "name": "Hammer and pick",
            "keywords": "hammer_and_pick"
        },
        {
            "glyph": "🛠️",
            "name": "Hammer and wrench",
            "keywords": "hammer_and_wrench"
        },
        {
            "glyph": "🗡️",
            "name": "Dagger",
            "keywords": "dagger"
        },
        {
            "glyph": "⚔️",
            "name": "Crossed swords",
            "keywords": "crossed_swords"
        },
        {
            "glyph": "💣",
            "name": "Bomb",
            "keywords": "bomb boom"
        },
        {
            "glyph": "🪃",
            "name": "Boomerang",
            "keywords": "boomerang"
        },
        {
            "glyph": "🏹",
            "name": "Bow and arrow",
            "keywords": "bow_and_arrow archery"
        },
        {
            "glyph": "🛡️",
            "name": "Shield",
            "keywords": "shield"
        },
        {
            "glyph": "🪚",
            "name": "Carpentry saw",
            "keywords": "carpentry_saw"
        },
        {
            "glyph": "🔧",
            "name": "Wrench",
            "keywords": "wrench tool"
        },
        {
            "glyph": "🪛",
            "name": "Screwdriver",
            "keywords": "screwdriver"
        },
        {
            "glyph": "🔩",
            "name": "Nut and bolt",
            "keywords": "nut_and_bolt"
        },
        {
            "glyph": "⚙️",
            "name": "Gear",
            "keywords": "gear"
        },
        {
            "glyph": "🗜️",
            "name": "Clamp",
            "keywords": "clamp"
        },
        {
            "glyph": "⚖️",
            "name": "Balance scale",
            "keywords": "balance_scale"
        },
        {
            "glyph": "🦯",
            "name": "White cane",
            "keywords": "probing_cane"
        },
        {
            "glyph": "🔗",
            "name": "Link",
            "keywords": "link"
        },
        {
            "glyph": "⛓️",
            "name": "Chains",
            "keywords": "chains"
        },
        {
            "glyph": "🪝",
            "name": "Hook",
            "keywords": "hook"
        },
        {
            "glyph": "🧰",
            "name": "Toolbox",
            "keywords": "toolbox"
        },
        {
            "glyph": "🧲",
            "name": "Magnet",
            "keywords": "magnet"
        },
        {
            "glyph": "🪜",
            "name": "Ladder",
            "keywords": "ladder"
        },
        {
            "glyph": "⚗️",
            "name": "Alembic",
            "keywords": "alembic"
        },
        {
            "glyph": "🧪",
            "name": "Test tube",
            "keywords": "test_tube"
        },
        {
            "glyph": "🧫",
            "name": "Petri dish",
            "keywords": "petri_dish"
        },
        {
            "glyph": "🧬",
            "name": "Dna",
            "keywords": "dna"
        },
        {
            "glyph": "🔬",
            "name": "Microscope",
            "keywords": "microscope science laboratory investigate"
        },
        {
            "glyph": "🔭",
            "name": "Telescope",
            "keywords": "telescope"
        },
        {
            "glyph": "📡",
            "name": "Satellite antenna",
            "keywords": "satellite signal"
        },
        {
            "glyph": "💉",
            "name": "Syringe",
            "keywords": "syringe health hospital needle"
        },
        {
            "glyph": "🩸",
            "name": "Drop of blood",
            "keywords": "drop_of_blood"
        },
        {
            "glyph": "💊",
            "name": "Pill",
            "keywords": "pill health medicine"
        },
        {
            "glyph": "🩹",
            "name": "Adhesive bandage",
            "keywords": "adhesive_bandage"
        },
        {
            "glyph": "🩼",
            "name": "Crutch",
            "keywords": "crutch"
        },
        {
            "glyph": "🩺",
            "name": "Stethoscope",
            "keywords": "stethoscope"
        },
        {
            "glyph": "🩻",
            "name": "X-ray",
            "keywords": "x_ray"
        },
        {
            "glyph": "🚪",
            "name": "Door",
            "keywords": "door"
        },
        {
            "glyph": "🛗",
            "name": "Elevator",
            "keywords": "elevator"
        },
        {
            "glyph": "🪞",
            "name": "Mirror",
            "keywords": "mirror"
        },
        {
            "glyph": "🪟",
            "name": "Window",
            "keywords": "window"
        },
        {
            "glyph": "🛏️",
            "name": "Bed",
            "keywords": "bed"
        },
        {
            "glyph": "🛋️",
            "name": "Couch and lamp",
            "keywords": "couch_and_lamp"
        },
        {
            "glyph": "🪑",
            "name": "Chair",
            "keywords": "chair"
        },
        {
            "glyph": "🚽",
            "name": "Toilet",
            "keywords": "toilet wc"
        },
        {
            "glyph": "🪠",
            "name": "Plunger",
            "keywords": "plunger"
        },
        {
            "glyph": "🚿",
            "name": "Shower",
            "keywords": "shower bath"
        },
        {
            "glyph": "🛁",
            "name": "Bathtub",
            "keywords": "bathtub"
        },
        {
            "glyph": "🪤",
            "name": "Mouse trap",
            "keywords": "mouse_trap"
        },
        {
            "glyph": "🪒",
            "name": "Razor",
            "keywords": "razor"
        },
        {
            "glyph": "🧴",
            "name": "Lotion bottle",
            "keywords": "lotion_bottle"
        },
        {
            "glyph": "🧷",
            "name": "Safety pin",
            "keywords": "safety_pin"
        },
        {
            "glyph": "🧹",
            "name": "Broom",
            "keywords": "broom"
        },
        {
            "glyph": "🧺",
            "name": "Basket",
            "keywords": "basket"
        },
        {
            "glyph": "🧻",
            "name": "Roll of paper",
            "keywords": "roll_of_paper toilet"
        },
        {
            "glyph": "🪣",
            "name": "Bucket",
            "keywords": "bucket"
        },
        {
            "glyph": "🧼",
            "name": "Soap",
            "keywords": "soap"
        },
        {
            "glyph": "🫧",
            "name": "Bubbles",
            "keywords": "bubbles"
        },
        {
            "glyph": "🪥",
            "name": "Toothbrush",
            "keywords": "toothbrush"
        },
        {
            "glyph": "🧽",
            "name": "Sponge",
            "keywords": "sponge"
        },
        {
            "glyph": "🧯",
            "name": "Fire extinguisher",
            "keywords": "fire_extinguisher"
        },
        {
            "glyph": "🛒",
            "name": "Shopping cart",
            "keywords": "shopping_cart"
        },
        {
            "glyph": "🚬",
            "name": "Cigarette",
            "keywords": "smoking cigarette"
        },
        {
            "glyph": "⚰️",
            "name": "Coffin",
            "keywords": "coffin funeral"
        },
        {
            "glyph": "🪦",
            "name": "Headstone",
            "keywords": "headstone"
        },
        {
            "glyph": "⚱️",
            "name": "Funeral urn",
            "keywords": "funeral_urn"
        },
        {
            "glyph": "🧿",
            "name": "Nazar amulet",
            "keywords": "nazar_amulet"
        },
        {
            "glyph": "🪬",
            "name": "Hamsa",
            "keywords": "hamsa"
        },
        {
            "glyph": "🗿",
            "name": "Moai",
            "keywords": "moyai stone"
        },
        {
            "glyph": "🪧",
            "name": "Placard",
            "keywords": "placard"
        },
        {
            "glyph": "🪪",
            "name": "Identification card",
            "keywords": "identification_card"
        },
        {
            "glyph": "🏧",
            "name": "Atm sign",
            "keywords": "atm"
        },
        {
            "glyph": "🚮",
            "name": "Litter in bin sign",
            "keywords": "put_litter_in_its_place"
        },
        {
            "glyph": "🚰",
            "name": "Potable water",
            "keywords": "potable_water"
        },
        {
            "glyph": "♿",
            "name": "Wheelchair symbol",
            "keywords": "wheelchair accessibility"
        },
        {
            "glyph": "🚹",
            "name": "Men’s room",
            "keywords": "mens"
        },
        {
            "glyph": "🚺",
            "name": "Women’s room",
            "keywords": "womens"
        },
        {
            "glyph": "🚻",
            "name": "Restroom",
            "keywords": "restroom toilet"
        },
        {
            "glyph": "🚼",
            "name": "Baby symbol",
            "keywords": "baby_symbol"
        },
        {
            "glyph": "🚾",
            "name": "Water closet",
            "keywords": "wc toilet restroom"
        },
        {
            "glyph": "🛂",
            "name": "Passport control",
            "keywords": "passport_control"
        },
        {
            "glyph": "🛃",
            "name": "Customs",
            "keywords": "customs"
        },
        {
            "glyph": "🛄",
            "name": "Baggage claim",
            "keywords": "baggage_claim airport"
        },
        {
            "glyph": "🛅",
            "name": "Left luggage",
            "keywords": "left_luggage"
        },
        {
            "glyph": "⚠️",
            "name": "Warning",
            "keywords": "warning wip"
        },
        {
            "glyph": "🚸",
            "name": "Children crossing",
            "keywords": "children_crossing"
        },
        {
            "glyph": "⛔",
            "name": "No entry",
            "keywords": "no_entry limit"
        },
        {
            "glyph": "🚫",
            "name": "Prohibited",
            "keywords": "no_entry_sign block forbidden"
        },
        {
            "glyph": "🚳",
            "name": "No bicycles",
            "keywords": "no_bicycles"
        },
        {
            "glyph": "🚭",
            "name": "No smoking",
            "keywords": "no_smoking"
        },
        {
            "glyph": "🚯",
            "name": "No littering",
            "keywords": "do_not_litter"
        },
        {
            "glyph": "🚱",
            "name": "Non-potable water",
            "keywords": "non-potable_water"
        },
        {
            "glyph": "🚷",
            "name": "No pedestrians",
            "keywords": "no_pedestrians"
        },
        {
            "glyph": "📵",
            "name": "No mobile phones",
            "keywords": "no_mobile_phones"
        },
        {
            "glyph": "🔞",
            "name": "No one under eighteen",
            "keywords": "underage"
        },
        {
            "glyph": "☢️",
            "name": "Radioactive",
            "keywords": "radioactive"
        },
        {
            "glyph": "☣️",
            "name": "Biohazard",
            "keywords": "biohazard"
        },
        {
            "glyph": "⬆️",
            "name": "Up arrow",
            "keywords": "arrow_up"
        },
        {
            "glyph": "↗️",
            "name": "Up-right arrow",
            "keywords": "arrow_upper_right"
        },
        {
            "glyph": "➡️",
            "name": "Right arrow",
            "keywords": "arrow_right"
        },
        {
            "glyph": "↘️",
            "name": "Down-right arrow",
            "keywords": "arrow_lower_right"
        },
        {
            "glyph": "⬇️",
            "name": "Down arrow",
            "keywords": "arrow_down"
        },
        {
            "glyph": "↙️",
            "name": "Down-left arrow",
            "keywords": "arrow_lower_left"
        },
        {
            "glyph": "⬅️",
            "name": "Left arrow",
            "keywords": "arrow_left"
        },
        {
            "glyph": "↖️",
            "name": "Up-left arrow",
            "keywords": "arrow_upper_left"
        },
        {
            "glyph": "↕️",
            "name": "Up-down arrow",
            "keywords": "arrow_up_down"
        },
        {
            "glyph": "↔️",
            "name": "Left-right arrow",
            "keywords": "left_right_arrow"
        },
        {
            "glyph": "↩️",
            "name": "Right arrow curving left",
            "keywords": "leftwards_arrow_with_hook return"
        },
        {
            "glyph": "↪️",
            "name": "Left arrow curving right",
            "keywords": "arrow_right_hook"
        },
        {
            "glyph": "⤴️",
            "name": "Right arrow curving up",
            "keywords": "arrow_heading_up"
        },
        {
            "glyph": "⤵️",
            "name": "Right arrow curving down",
            "keywords": "arrow_heading_down"
        },
        {
            "glyph": "🔃",
            "name": "Clockwise vertical arrows",
            "keywords": "arrows_clockwise"
        },
        {
            "glyph": "🔄",
            "name": "Counterclockwise arrows button",
            "keywords": "arrows_counterclockwise sync"
        },
        {
            "glyph": "🔙",
            "name": "Back arrow",
            "keywords": "back"
        },
        {
            "glyph": "🔚",
            "name": "End arrow",
            "keywords": "end"
        },
        {
            "glyph": "🔛",
            "name": "On! arrow",
            "keywords": "on"
        },
        {
            "glyph": "🔜",
            "name": "Soon arrow",
            "keywords": "soon"
        },
        {
            "glyph": "🔝",
            "name": "Top arrow",
            "keywords": "top"
        },
        {
            "glyph": "🛐",
            "name": "Place of worship",
            "keywords": "place_of_worship"
        },
        {
            "glyph": "⚛️",
            "name": "Atom symbol",
            "keywords": "atom_symbol"
        },
        {
            "glyph": "🕉️",
            "name": "Om",
            "keywords": "om"
        },
        {
            "glyph": "✡️",
            "name": "Star of david",
            "keywords": "star_of_david"
        },
        {
            "glyph": "☸️",
            "name": "Wheel of dharma",
            "keywords": "wheel_of_dharma"
        },
        {
            "glyph": "☯️",
            "name": "Yin yang",
            "keywords": "yin_yang"
        },
        {
            "glyph": "✝️",
            "name": "Latin cross",
            "keywords": "latin_cross"
        },
        {
            "glyph": "☦️",
            "name": "Orthodox cross",
            "keywords": "orthodox_cross"
        },
        {
            "glyph": "☪️",
            "name": "Star and crescent",
            "keywords": "star_and_crescent"
        },
        {
            "glyph": "☮️",
            "name": "Peace symbol",
            "keywords": "peace_symbol"
        },
        {
            "glyph": "🕎",
            "name": "Menorah",
            "keywords": "menorah"
        },
        {
            "glyph": "🔯",
            "name": "Dotted six-pointed star",
            "keywords": "six_pointed_star"
        },
        {
            "glyph": "🪯",
            "name": "Khanda",
            "keywords": "khanda"
        },
        {
            "glyph": "♈",
            "name": "Aries",
            "keywords": "aries"
        },
        {
            "glyph": "♉",
            "name": "Taurus",
            "keywords": "taurus"
        },
        {
            "glyph": "♊",
            "name": "Gemini",
            "keywords": "gemini"
        },
        {
            "glyph": "♋",
            "name": "Cancer",
            "keywords": "cancer"
        },
        {
            "glyph": "♌",
            "name": "Leo",
            "keywords": "leo"
        },
        {
            "glyph": "♍",
            "name": "Virgo",
            "keywords": "virgo"
        },
        {
            "glyph": "♎",
            "name": "Libra",
            "keywords": "libra"
        },
        {
            "glyph": "♏",
            "name": "Scorpio",
            "keywords": "scorpius"
        },
        {
            "glyph": "♐",
            "name": "Sagittarius",
            "keywords": "sagittarius"
        },
        {
            "glyph": "♑",
            "name": "Capricorn",
            "keywords": "capricorn"
        },
        {
            "glyph": "♒",
            "name": "Aquarius",
            "keywords": "aquarius"
        },
        {
            "glyph": "♓",
            "name": "Pisces",
            "keywords": "pisces"
        },
        {
            "glyph": "⛎",
            "name": "Ophiuchus",
            "keywords": "ophiuchus"
        },
        {
            "glyph": "🔀",
            "name": "Shuffle tracks button",
            "keywords": "twisted_rightwards_arrows shuffle"
        },
        {
            "glyph": "🔁",
            "name": "Repeat button",
            "keywords": "repeat loop"
        },
        {
            "glyph": "🔂",
            "name": "Repeat single button",
            "keywords": "repeat_one"
        },
        {
            "glyph": "▶️",
            "name": "Play button",
            "keywords": "arrow_forward"
        },
        {
            "glyph": "⏩",
            "name": "Fast-forward button",
            "keywords": "fast_forward"
        },
        {
            "glyph": "⏭️",
            "name": "Next track button",
            "keywords": "next_track_button"
        },
        {
            "glyph": "⏯️",
            "name": "Play or pause button",
            "keywords": "play_or_pause_button"
        },
        {
            "glyph": "◀️",
            "name": "Reverse button",
            "keywords": "arrow_backward"
        },
        {
            "glyph": "⏪",
            "name": "Fast reverse button",
            "keywords": "rewind"
        },
        {
            "glyph": "⏮️",
            "name": "Last track button",
            "keywords": "previous_track_button"
        },
        {
            "glyph": "🔼",
            "name": "Upwards button",
            "keywords": "arrow_up_small"
        },
        {
            "glyph": "⏫",
            "name": "Fast up button",
            "keywords": "arrow_double_up"
        },
        {
            "glyph": "🔽",
            "name": "Downwards button",
            "keywords": "arrow_down_small"
        },
        {
            "glyph": "⏬",
            "name": "Fast down button",
            "keywords": "arrow_double_down"
        },
        {
            "glyph": "⏸️",
            "name": "Pause button",
            "keywords": "pause_button"
        },
        {
            "glyph": "⏹️",
            "name": "Stop button",
            "keywords": "stop_button"
        },
        {
            "glyph": "⏺️",
            "name": "Record button",
            "keywords": "record_button"
        },
        {
            "glyph": "⏏️",
            "name": "Eject button",
            "keywords": "eject_button"
        },
        {
            "glyph": "🎦",
            "name": "Cinema",
            "keywords": "cinema film movie"
        },
        {
            "glyph": "🔅",
            "name": "Dim button",
            "keywords": "low_brightness"
        },
        {
            "glyph": "🔆",
            "name": "Bright button",
            "keywords": "high_brightness"
        },
        {
            "glyph": "📶",
            "name": "Antenna bars",
            "keywords": "signal_strength wifi"
        },
        {
            "glyph": "🛜",
            "name": "Wireless",
            "keywords": "wireless wifi"
        },
        {
            "glyph": "📳",
            "name": "Vibration mode",
            "keywords": "vibration_mode"
        },
        {
            "glyph": "📴",
            "name": "Mobile phone off",
            "keywords": "mobile_phone_off mute off"
        },
        {
            "glyph": "♀️",
            "name": "Female sign",
            "keywords": "female_sign"
        },
        {
            "glyph": "♂️",
            "name": "Male sign",
            "keywords": "male_sign"
        },
        {
            "glyph": "⚧️",
            "name": "Transgender symbol",
            "keywords": "transgender_symbol"
        },
        {
            "glyph": "✖️",
            "name": "Multiply",
            "keywords": "heavy_multiplication_x"
        },
        {
            "glyph": "➕",
            "name": "Plus",
            "keywords": "heavy_plus_sign"
        },
        {
            "glyph": "➖",
            "name": "Minus",
            "keywords": "heavy_minus_sign"
        },
        {
            "glyph": "➗",
            "name": "Divide",
            "keywords": "heavy_division_sign"
        },
        {
            "glyph": "🟰",
            "name": "Heavy equals sign",
            "keywords": "heavy_equals_sign"
        },
        {
            "glyph": "♾️",
            "name": "Infinity",
            "keywords": "infinity"
        },
        {
            "glyph": "‼️",
            "name": "Double exclamation mark",
            "keywords": "bangbang"
        },
        {
            "glyph": "⁉️",
            "name": "Exclamation question mark",
            "keywords": "interrobang"
        },
        {
            "glyph": "❓",
            "name": "Red question mark",
            "keywords": "question confused"
        },
        {
            "glyph": "❔",
            "name": "White question mark",
            "keywords": "grey_question"
        },
        {
            "glyph": "❕",
            "name": "White exclamation mark",
            "keywords": "grey_exclamation"
        },
        {
            "glyph": "❗",
            "name": "Red exclamation mark",
            "keywords": "exclamation heavy_exclamation_mark bang"
        },
        {
            "glyph": "〰️",
            "name": "Wavy dash",
            "keywords": "wavy_dash"
        },
        {
            "glyph": "💱",
            "name": "Currency exchange",
            "keywords": "currency_exchange"
        },
        {
            "glyph": "💲",
            "name": "Heavy dollar sign",
            "keywords": "heavy_dollar_sign"
        },
        {
            "glyph": "⚕️",
            "name": "Medical symbol",
            "keywords": "medical_symbol"
        },
        {
            "glyph": "♻️",
            "name": "Recycling symbol",
            "keywords": "recycle environment green"
        },
        {
            "glyph": "⚜️",
            "name": "Fleur-de-lis",
            "keywords": "fleur_de_lis"
        },
        {
            "glyph": "🔱",
            "name": "Trident emblem",
            "keywords": "trident"
        },
        {
            "glyph": "📛",
            "name": "Name badge",
            "keywords": "name_badge"
        },
        {
            "glyph": "🔰",
            "name": "Japanese symbol for beginner",
            "keywords": "beginner"
        },
        {
            "glyph": "⭕",
            "name": "Hollow red circle",
            "keywords": "o"
        },
        {
            "glyph": "✅",
            "name": "Check mark button",
            "keywords": "white_check_mark"
        },
        {
            "glyph": "☑️",
            "name": "Check box with check",
            "keywords": "ballot_box_with_check"
        },
        {
            "glyph": "✔️",
            "name": "Check mark",
            "keywords": "heavy_check_mark"
        },
        {
            "glyph": "❌",
            "name": "Cross mark",
            "keywords": "x"
        },
        {
            "glyph": "❎",
            "name": "Cross mark button",
            "keywords": "negative_squared_cross_mark"
        },
        {
            "glyph": "➰",
            "name": "Curly loop",
            "keywords": "curly_loop"
        },
        {
            "glyph": "➿",
            "name": "Double curly loop",
            "keywords": "loop"
        },
        {
            "glyph": "〽️",
            "name": "Part alternation mark",
            "keywords": "part_alternation_mark"
        },
        {
            "glyph": "✳️",
            "name": "Eight-spoked asterisk",
            "keywords": "eight_spoked_asterisk"
        },
        {
            "glyph": "✴️",
            "name": "Eight-pointed star",
            "keywords": "eight_pointed_black_star"
        },
        {
            "glyph": "❇️",
            "name": "Sparkle",
            "keywords": "sparkle"
        },
        {
            "glyph": "©️",
            "name": "Copyright",
            "keywords": "copyright"
        },
        {
            "glyph": "®️",
            "name": "Registered",
            "keywords": "registered"
        },
        {
            "glyph": "™️",
            "name": "Trade mark",
            "keywords": "tm trademark"
        },
        {
            "glyph": "#️⃣",
            "name": "Keycap: #",
            "keywords": "hash number"
        },
        {
            "glyph": "*️⃣",
            "name": "Keycap: *",
            "keywords": "asterisk"
        },
        {
            "glyph": "0️⃣",
            "name": "Keycap: 0",
            "keywords": "zero"
        },
        {
            "glyph": "1️⃣",
            "name": "Keycap: 1",
            "keywords": "one"
        },
        {
            "glyph": "2️⃣",
            "name": "Keycap: 2",
            "keywords": "two"
        },
        {
            "glyph": "3️⃣",
            "name": "Keycap: 3",
            "keywords": "three"
        },
        {
            "glyph": "4️⃣",
            "name": "Keycap: 4",
            "keywords": "four"
        },
        {
            "glyph": "5️⃣",
            "name": "Keycap: 5",
            "keywords": "five"
        },
        {
            "glyph": "6️⃣",
            "name": "Keycap: 6",
            "keywords": "six"
        },
        {
            "glyph": "7️⃣",
            "name": "Keycap: 7",
            "keywords": "seven"
        },
        {
            "glyph": "8️⃣",
            "name": "Keycap: 8",
            "keywords": "eight"
        },
        {
            "glyph": "9️⃣",
            "name": "Keycap: 9",
            "keywords": "nine"
        },
        {
            "glyph": "🔟",
            "name": "Keycap: 10",
            "keywords": "keycap_ten"
        },
        {
            "glyph": "🔠",
            "name": "Input latin uppercase",
            "keywords": "capital_abcd letters"
        },
        {
            "glyph": "🔡",
            "name": "Input latin lowercase",
            "keywords": "abcd"
        },
        {
            "glyph": "🔢",
            "name": "Input numbers",
            "keywords": "1234 numbers"
        },
        {
            "glyph": "🔣",
            "name": "Input symbols",
            "keywords": "symbols"
        },
        {
            "glyph": "🔤",
            "name": "Input latin letters",
            "keywords": "abc alphabet"
        },
        {
            "glyph": "🅰️",
            "name": "A button (blood type)",
            "keywords": "a"
        },
        {
            "glyph": "🆎",
            "name": "Ab button (blood type)",
            "keywords": "ab"
        },
        {
            "glyph": "🅱️",
            "name": "B button (blood type)",
            "keywords": "b"
        },
        {
            "glyph": "🆑",
            "name": "Cl button",
            "keywords": "cl"
        },
        {
            "glyph": "🆒",
            "name": "Cool button",
            "keywords": "cool"
        },
        {
            "glyph": "🆓",
            "name": "Free button",
            "keywords": "free"
        },
        {
            "glyph": "ℹ️",
            "name": "Information",
            "keywords": "information_source"
        },
        {
            "glyph": "🆔",
            "name": "Id button",
            "keywords": "id"
        },
        {
            "glyph": "Ⓜ️",
            "name": "Circled m",
            "keywords": "m"
        },
        {
            "glyph": "🆕",
            "name": "New button",
            "keywords": "new fresh"
        },
        {
            "glyph": "🆖",
            "name": "Ng button",
            "keywords": "ng"
        },
        {
            "glyph": "🅾️",
            "name": "O button (blood type)",
            "keywords": "o2"
        },
        {
            "glyph": "🆗",
            "name": "Ok button",
            "keywords": "ok yes"
        },
        {
            "glyph": "🅿️",
            "name": "P button",
            "keywords": "parking"
        },
        {
            "glyph": "🆘",
            "name": "Sos button",
            "keywords": "sos help emergency"
        },
        {
            "glyph": "🆙",
            "name": "Up! button",
            "keywords": "up"
        },
        {
            "glyph": "🆚",
            "name": "Vs button",
            "keywords": "vs"
        },
        {
            "glyph": "🈁",
            "name": "Japanese “here” button",
            "keywords": "koko"
        },
        {
            "glyph": "🈂️",
            "name": "Japanese “service charge” button",
            "keywords": "sa"
        },
        {
            "glyph": "🈷️",
            "name": "Japanese “monthly amount” button",
            "keywords": "u6708"
        },
        {
            "glyph": "🈶",
            "name": "Japanese “not free of charge” button",
            "keywords": "u6709"
        },
        {
            "glyph": "🈯",
            "name": "Japanese “reserved” button",
            "keywords": "u6307"
        },
        {
            "glyph": "🉐",
            "name": "Japanese “bargain” button",
            "keywords": "ideograph_advantage"
        },
        {
            "glyph": "🈹",
            "name": "Japanese “discount” button",
            "keywords": "u5272"
        },
        {
            "glyph": "🈚",
            "name": "Japanese “free of charge” button",
            "keywords": "u7121"
        },
        {
            "glyph": "🈲",
            "name": "Japanese “prohibited” button",
            "keywords": "u7981"
        },
        {
            "glyph": "🉑",
            "name": "Japanese “acceptable” button",
            "keywords": "accept"
        },
        {
            "glyph": "🈸",
            "name": "Japanese “application” button",
            "keywords": "u7533"
        },
        {
            "glyph": "🈴",
            "name": "Japanese “passing grade” button",
            "keywords": "u5408"
        },
        {
            "glyph": "🈳",
            "name": "Japanese “vacancy” button",
            "keywords": "u7a7a"
        },
        {
            "glyph": "㊗️",
            "name": "Japanese “congratulations” button",
            "keywords": "congratulations"
        },
        {
            "glyph": "㊙️",
            "name": "Japanese “secret” button",
            "keywords": "secret"
        },
        {
            "glyph": "🈺",
            "name": "Japanese “open for business” button",
            "keywords": "u55b6"
        },
        {
            "glyph": "🈵",
            "name": "Japanese “no vacancy” button",
            "keywords": "u6e80"
        },
        {
            "glyph": "🔴",
            "name": "Red circle",
            "keywords": "red_circle"
        },
        {
            "glyph": "🟠",
            "name": "Orange circle",
            "keywords": "orange_circle"
        },
        {
            "glyph": "🟡",
            "name": "Yellow circle",
            "keywords": "yellow_circle"
        },
        {
            "glyph": "🟢",
            "name": "Green circle",
            "keywords": "green_circle"
        },
        {
            "glyph": "🔵",
            "name": "Blue circle",
            "keywords": "large_blue_circle"
        },
        {
            "glyph": "🟣",
            "name": "Purple circle",
            "keywords": "purple_circle"
        },
        {
            "glyph": "🟤",
            "name": "Brown circle",
            "keywords": "brown_circle"
        },
        {
            "glyph": "⚫",
            "name": "Black circle",
            "keywords": "black_circle"
        },
        {
            "glyph": "⚪",
            "name": "White circle",
            "keywords": "white_circle"
        },
        {
            "glyph": "🟥",
            "name": "Red square",
            "keywords": "red_square"
        },
        {
            "glyph": "🟧",
            "name": "Orange square",
            "keywords": "orange_square"
        },
        {
            "glyph": "🟨",
            "name": "Yellow square",
            "keywords": "yellow_square"
        },
        {
            "glyph": "🟩",
            "name": "Green square",
            "keywords": "green_square"
        },
        {
            "glyph": "🟦",
            "name": "Blue square",
            "keywords": "blue_square"
        },
        {
            "glyph": "🟪",
            "name": "Purple square",
            "keywords": "purple_square"
        },
        {
            "glyph": "🟫",
            "name": "Brown square",
            "keywords": "brown_square"
        },
        {
            "glyph": "⬛",
            "name": "Black large square",
            "keywords": "black_large_square"
        },
        {
            "glyph": "⬜",
            "name": "White large square",
            "keywords": "white_large_square"
        },
        {
            "glyph": "◼️",
            "name": "Black medium square",
            "keywords": "black_medium_square"
        },
        {
            "glyph": "◻️",
            "name": "White medium square",
            "keywords": "white_medium_square"
        },
        {
            "glyph": "◾",
            "name": "Black medium-small square",
            "keywords": "black_medium_small_square"
        },
        {
            "glyph": "◽",
            "name": "White medium-small square",
            "keywords": "white_medium_small_square"
        },
        {
            "glyph": "▪️",
            "name": "Black small square",
            "keywords": "black_small_square"
        },
        {
            "glyph": "▫️",
            "name": "White small square",
            "keywords": "white_small_square"
        },
        {
            "glyph": "🔶",
            "name": "Large orange diamond",
            "keywords": "large_orange_diamond"
        },
        {
            "glyph": "🔷",
            "name": "Large blue diamond",
            "keywords": "large_blue_diamond"
        },
        {
            "glyph": "🔸",
            "name": "Small orange diamond",
            "keywords": "small_orange_diamond"
        },
        {
            "glyph": "🔹",
            "name": "Small blue diamond",
            "keywords": "small_blue_diamond"
        },
        {
            "glyph": "🔺",
            "name": "Red triangle pointed up",
            "keywords": "small_red_triangle"
        },
        {
            "glyph": "🔻",
            "name": "Red triangle pointed down",
            "keywords": "small_red_triangle_down"
        },
        {
            "glyph": "💠",
            "name": "Diamond with a dot",
            "keywords": "diamond_shape_with_a_dot_inside"
        },
        {
            "glyph": "🔘",
            "name": "Radio button",
            "keywords": "radio_button"
        },
        {
            "glyph": "🔳",
            "name": "White square button",
            "keywords": "white_square_button"
        },
        {
            "glyph": "🔲",
            "name": "Black square button",
            "keywords": "black_square_button"
        },
        {
            "glyph": "🏁",
            "name": "Chequered flag",
            "keywords": "checkered_flag milestone finish"
        },
        {
            "glyph": "🚩",
            "name": "Triangular flag",
            "keywords": "triangular_flag_on_post"
        },
        {
            "glyph": "🎌",
            "name": "Crossed flags",
            "keywords": "crossed_flags"
        },
        {
            "glyph": "🏴",
            "name": "Black flag",
            "keywords": "black_flag"
        },
        {
            "glyph": "🏳️",
            "name": "White flag",
            "keywords": "white_flag"
        },
        {
            "glyph": "🏳️‍🌈",
            "name": "Rainbow flag",
            "keywords": "rainbow_flag pride"
        },
        {
            "glyph": "🏳️‍⚧️",
            "name": "Transgender flag",
            "keywords": "transgender_flag"
        },
        {
            "glyph": "🏴‍☠️",
            "name": "Pirate flag",
            "keywords": "pirate_flag"
        },
        {
            "glyph": "🇦🇨",
            "name": "Flag: ascension island",
            "keywords": "ascension_island"
        },
        {
            "glyph": "🇦🇩",
            "name": "Flag: andorra",
            "keywords": "andorra"
        },
        {
            "glyph": "🇦🇪",
            "name": "Flag: united arab emirates",
            "keywords": "united_arab_emirates"
        },
        {
            "glyph": "🇦🇫",
            "name": "Flag: afghanistan",
            "keywords": "afghanistan"
        },
        {
            "glyph": "🇦🇬",
            "name": "Flag: antigua & barbuda",
            "keywords": "antigua_barbuda"
        },
        {
            "glyph": "🇦🇮",
            "name": "Flag: anguilla",
            "keywords": "anguilla"
        },
        {
            "glyph": "🇦🇱",
            "name": "Flag: albania",
            "keywords": "albania"
        },
        {
            "glyph": "🇦🇲",
            "name": "Flag: armenia",
            "keywords": "armenia"
        },
        {
            "glyph": "🇦🇴",
            "name": "Flag: angola",
            "keywords": "angola"
        },
        {
            "glyph": "🇦🇶",
            "name": "Flag: antarctica",
            "keywords": "antarctica"
        },
        {
            "glyph": "🇦🇷",
            "name": "Flag: argentina",
            "keywords": "argentina"
        },
        {
            "glyph": "🇦🇸",
            "name": "Flag: american samoa",
            "keywords": "american_samoa"
        },
        {
            "glyph": "🇦🇹",
            "name": "Flag: austria",
            "keywords": "austria"
        },
        {
            "glyph": "🇦🇺",
            "name": "Flag: australia",
            "keywords": "australia"
        },
        {
            "glyph": "🇦🇼",
            "name": "Flag: aruba",
            "keywords": "aruba"
        },
        {
            "glyph": "🇦🇽",
            "name": "Flag: åland islands",
            "keywords": "aland_islands"
        },
        {
            "glyph": "🇦🇿",
            "name": "Flag: azerbaijan",
            "keywords": "azerbaijan"
        },
        {
            "glyph": "🇧🇦",
            "name": "Flag: bosnia & herzegovina",
            "keywords": "bosnia_herzegovina"
        },
        {
            "glyph": "🇧🇧",
            "name": "Flag: barbados",
            "keywords": "barbados"
        },
        {
            "glyph": "🇧🇩",
            "name": "Flag: bangladesh",
            "keywords": "bangladesh"
        },
        {
            "glyph": "🇧🇪",
            "name": "Flag: belgium",
            "keywords": "belgium"
        },
        {
            "glyph": "🇧🇫",
            "name": "Flag: burkina faso",
            "keywords": "burkina_faso"
        },
        {
            "glyph": "🇧🇬",
            "name": "Flag: bulgaria",
            "keywords": "bulgaria"
        },
        {
            "glyph": "🇧🇭",
            "name": "Flag: bahrain",
            "keywords": "bahrain"
        },
        {
            "glyph": "🇧🇮",
            "name": "Flag: burundi",
            "keywords": "burundi"
        },
        {
            "glyph": "🇧🇯",
            "name": "Flag: benin",
            "keywords": "benin"
        },
        {
            "glyph": "🇧🇱",
            "name": "Flag: st. barthélemy",
            "keywords": "st_barthelemy"
        },
        {
            "glyph": "🇧🇲",
            "name": "Flag: bermuda",
            "keywords": "bermuda"
        },
        {
            "glyph": "🇧🇳",
            "name": "Flag: brunei",
            "keywords": "brunei"
        },
        {
            "glyph": "🇧🇴",
            "name": "Flag: bolivia",
            "keywords": "bolivia"
        },
        {
            "glyph": "🇧🇶",
            "name": "Flag: caribbean netherlands",
            "keywords": "caribbean_netherlands"
        },
        {
            "glyph": "🇧🇷",
            "name": "Flag: brazil",
            "keywords": "brazil"
        },
        {
            "glyph": "🇧🇸",
            "name": "Flag: bahamas",
            "keywords": "bahamas"
        },
        {
            "glyph": "🇧🇹",
            "name": "Flag: bhutan",
            "keywords": "bhutan"
        },
        {
            "glyph": "🇧🇻",
            "name": "Flag: bouvet island",
            "keywords": "bouvet_island"
        },
        {
            "glyph": "🇧🇼",
            "name": "Flag: botswana",
            "keywords": "botswana"
        },
        {
            "glyph": "🇧🇾",
            "name": "Flag: belarus",
            "keywords": "belarus"
        },
        {
            "glyph": "🇧🇿",
            "name": "Flag: belize",
            "keywords": "belize"
        },
        {
            "glyph": "🇨🇦",
            "name": "Flag: canada",
            "keywords": "canada"
        },
        {
            "glyph": "🇨🇨",
            "name": "Flag: cocos (keeling) islands",
            "keywords": "cocos_islands keeling"
        },
        {
            "glyph": "🇨🇩",
            "name": "Flag: congo - kinshasa",
            "keywords": "congo_kinshasa"
        },
        {
            "glyph": "🇨🇫",
            "name": "Flag: central african republic",
            "keywords": "central_african_republic"
        },
        {
            "glyph": "🇨🇬",
            "name": "Flag: congo - brazzaville",
            "keywords": "congo_brazzaville"
        },
        {
            "glyph": "🇨🇭",
            "name": "Flag: switzerland",
            "keywords": "switzerland"
        },
        {
            "glyph": "🇨🇮",
            "name": "Flag: côte d’ivoire",
            "keywords": "cote_divoire ivory"
        },
        {
            "glyph": "🇨🇰",
            "name": "Flag: cook islands",
            "keywords": "cook_islands"
        },
        {
            "glyph": "🇨🇱",
            "name": "Flag: chile",
            "keywords": "chile"
        },
        {
            "glyph": "🇨🇲",
            "name": "Flag: cameroon",
            "keywords": "cameroon"
        },
        {
            "glyph": "🇨🇳",
            "name": "Flag: china",
            "keywords": "cn china"
        },
        {
            "glyph": "🇨🇴",
            "name": "Flag: colombia",
            "keywords": "colombia"
        },
        {
            "glyph": "🇨🇵",
            "name": "Flag: clipperton island",
            "keywords": "clipperton_island"
        },
        {
            "glyph": "🇨🇷",
            "name": "Flag: costa rica",
            "keywords": "costa_rica"
        },
        {
            "glyph": "🇨🇺",
            "name": "Flag: cuba",
            "keywords": "cuba"
        },
        {
            "glyph": "🇨🇻",
            "name": "Flag: cape verde",
            "keywords": "cape_verde"
        },
        {
            "glyph": "🇨🇼",
            "name": "Flag: curaçao",
            "keywords": "curacao"
        },
        {
            "glyph": "🇨🇽",
            "name": "Flag: christmas island",
            "keywords": "christmas_island"
        },
        {
            "glyph": "🇨🇾",
            "name": "Flag: cyprus",
            "keywords": "cyprus"
        },
        {
            "glyph": "🇨🇿",
            "name": "Flag: czechia",
            "keywords": "czech_republic"
        },
        {
            "glyph": "🇩🇪",
            "name": "Flag: germany",
            "keywords": "de flag germany"
        },
        {
            "glyph": "🇩🇬",
            "name": "Flag: diego garcia",
            "keywords": "diego_garcia"
        },
        {
            "glyph": "🇩🇯",
            "name": "Flag: djibouti",
            "keywords": "djibouti"
        },
        {
            "glyph": "🇩🇰",
            "name": "Flag: denmark",
            "keywords": "denmark"
        },
        {
            "glyph": "🇩🇲",
            "name": "Flag: dominica",
            "keywords": "dominica"
        },
        {
            "glyph": "🇩🇴",
            "name": "Flag: dominican republic",
            "keywords": "dominican_republic"
        },
        {
            "glyph": "🇩🇿",
            "name": "Flag: algeria",
            "keywords": "algeria"
        },
        {
            "glyph": "🇪🇦",
            "name": "Flag: ceuta & melilla",
            "keywords": "ceuta_melilla"
        },
        {
            "glyph": "🇪🇨",
            "name": "Flag: ecuador",
            "keywords": "ecuador"
        },
        {
            "glyph": "🇪🇪",
            "name": "Flag: estonia",
            "keywords": "estonia"
        },
        {
            "glyph": "🇪🇬",
            "name": "Flag: egypt",
            "keywords": "egypt"
        },
        {
            "glyph": "🇪🇭",
            "name": "Flag: western sahara",
            "keywords": "western_sahara"
        },
        {
            "glyph": "🇪🇷",
            "name": "Flag: eritrea",
            "keywords": "eritrea"
        },
        {
            "glyph": "🇪🇸",
            "name": "Flag: spain",
            "keywords": "es spain"
        },
        {
            "glyph": "🇪🇹",
            "name": "Flag: ethiopia",
            "keywords": "ethiopia"
        },
        {
            "glyph": "🇪🇺",
            "name": "Flag: european union",
            "keywords": "eu european_union"
        },
        {
            "glyph": "🇫🇮",
            "name": "Flag: finland",
            "keywords": "finland"
        },
        {
            "glyph": "🇫🇯",
            "name": "Flag: fiji",
            "keywords": "fiji"
        },
        {
            "glyph": "🇫🇰",
            "name": "Flag: falkland islands",
            "keywords": "falkland_islands"
        },
        {
            "glyph": "🇫🇲",
            "name": "Flag: micronesia",
            "keywords": "micronesia"
        },
        {
            "glyph": "🇫🇴",
            "name": "Flag: faroe islands",
            "keywords": "faroe_islands"
        },
        {
            "glyph": "🇫🇷",
            "name": "Flag: france",
            "keywords": "fr france french"
        },
        {
            "glyph": "🇬🇦",
            "name": "Flag: gabon",
            "keywords": "gabon"
        },
        {
            "glyph": "🇬🇧",
            "name": "Flag: united kingdom",
            "keywords": "gb uk flag british"
        },
        {
            "glyph": "🇬🇩",
            "name": "Flag: grenada",
            "keywords": "grenada"
        },
        {
            "glyph": "🇬🇪",
            "name": "Flag: georgia",
            "keywords": "georgia"
        },
        {
            "glyph": "🇬🇫",
            "name": "Flag: french guiana",
            "keywords": "french_guiana"
        },
        {
            "glyph": "🇬🇬",
            "name": "Flag: guernsey",
            "keywords": "guernsey"
        },
        {
            "glyph": "🇬🇭",
            "name": "Flag: ghana",
            "keywords": "ghana"
        },
        {
            "glyph": "🇬🇮",
            "name": "Flag: gibraltar",
            "keywords": "gibraltar"
        },
        {
            "glyph": "🇬🇱",
            "name": "Flag: greenland",
            "keywords": "greenland"
        },
        {
            "glyph": "🇬🇲",
            "name": "Flag: gambia",
            "keywords": "gambia"
        },
        {
            "glyph": "🇬🇳",
            "name": "Flag: guinea",
            "keywords": "guinea"
        },
        {
            "glyph": "🇬🇵",
            "name": "Flag: guadeloupe",
            "keywords": "guadeloupe"
        },
        {
            "glyph": "🇬🇶",
            "name": "Flag: equatorial guinea",
            "keywords": "equatorial_guinea"
        },
        {
            "glyph": "🇬🇷",
            "name": "Flag: greece",
            "keywords": "greece"
        },
        {
            "glyph": "🇬🇸",
            "name": "Flag: south georgia & south sandwich islands",
            "keywords": "south_georgia_south_sandwich_islands"
        },
        {
            "glyph": "🇬🇹",
            "name": "Flag: guatemala",
            "keywords": "guatemala"
        },
        {
            "glyph": "🇬🇺",
            "name": "Flag: guam",
            "keywords": "guam"
        },
        {
            "glyph": "🇬🇼",
            "name": "Flag: guinea-bissau",
            "keywords": "guinea_bissau"
        },
        {
            "glyph": "🇬🇾",
            "name": "Flag: guyana",
            "keywords": "guyana"
        },
        {
            "glyph": "🇭🇰",
            "name": "Flag: hong kong sar china",
            "keywords": "hong_kong"
        },
        {
            "glyph": "🇭🇲",
            "name": "Flag: heard & mcdonald islands",
            "keywords": "heard_mcdonald_islands"
        },
        {
            "glyph": "🇭🇳",
            "name": "Flag: honduras",
            "keywords": "honduras"
        },
        {
            "glyph": "🇭🇷",
            "name": "Flag: croatia",
            "keywords": "croatia"
        },
        {
            "glyph": "🇭🇹",
            "name": "Flag: haiti",
            "keywords": "haiti"
        },
        {
            "glyph": "🇭🇺",
            "name": "Flag: hungary",
            "keywords": "hungary"
        },
        {
            "glyph": "🇮🇨",
            "name": "Flag: canary islands",
            "keywords": "canary_islands"
        },
        {
            "glyph": "🇮🇩",
            "name": "Flag: indonesia",
            "keywords": "indonesia"
        },
        {
            "glyph": "🇮🇪",
            "name": "Flag: ireland",
            "keywords": "ireland"
        },
        {
            "glyph": "🇮🇱",
            "name": "Flag: israel",
            "keywords": "israel"
        },
        {
            "glyph": "🇮🇲",
            "name": "Flag: isle of man",
            "keywords": "isle_of_man"
        },
        {
            "glyph": "🇮🇳",
            "name": "Flag: india",
            "keywords": "india"
        },
        {
            "glyph": "🇮🇴",
            "name": "Flag: british indian ocean territory",
            "keywords": "british_indian_ocean_territory"
        },
        {
            "glyph": "🇮🇶",
            "name": "Flag: iraq",
            "keywords": "iraq"
        },
        {
            "glyph": "🇮🇷",
            "name": "Flag: iran",
            "keywords": "iran"
        },
        {
            "glyph": "🇮🇸",
            "name": "Flag: iceland",
            "keywords": "iceland"
        },
        {
            "glyph": "🇮🇹",
            "name": "Flag: italy",
            "keywords": "it italy"
        },
        {
            "glyph": "🇯🇪",
            "name": "Flag: jersey",
            "keywords": "jersey"
        },
        {
            "glyph": "🇯🇲",
            "name": "Flag: jamaica",
            "keywords": "jamaica"
        },
        {
            "glyph": "🇯🇴",
            "name": "Flag: jordan",
            "keywords": "jordan"
        },
        {
            "glyph": "🇯🇵",
            "name": "Flag: japan",
            "keywords": "jp japan"
        },
        {
            "glyph": "🇰🇪",
            "name": "Flag: kenya",
            "keywords": "kenya"
        },
        {
            "glyph": "🇰🇬",
            "name": "Flag: kyrgyzstan",
            "keywords": "kyrgyzstan"
        },
        {
            "glyph": "🇰🇭",
            "name": "Flag: cambodia",
            "keywords": "cambodia"
        },
        {
            "glyph": "🇰🇮",
            "name": "Flag: kiribati",
            "keywords": "kiribati"
        },
        {
            "glyph": "🇰🇲",
            "name": "Flag: comoros",
            "keywords": "comoros"
        },
        {
            "glyph": "🇰🇳",
            "name": "Flag: st. kitts & nevis",
            "keywords": "st_kitts_nevis"
        },
        {
            "glyph": "🇰🇵",
            "name": "Flag: north korea",
            "keywords": "north_korea"
        },
        {
            "glyph": "🇰🇷",
            "name": "Flag: south korea",
            "keywords": "kr korea"
        },
        {
            "glyph": "🇰🇼",
            "name": "Flag: kuwait",
            "keywords": "kuwait"
        },
        {
            "glyph": "🇰🇾",
            "name": "Flag: cayman islands",
            "keywords": "cayman_islands"
        },
        {
            "glyph": "🇰🇿",
            "name": "Flag: kazakhstan",
            "keywords": "kazakhstan"
        },
        {
            "glyph": "🇱🇦",
            "name": "Flag: laos",
            "keywords": "laos"
        },
        {
            "glyph": "🇱🇧",
            "name": "Flag: lebanon",
            "keywords": "lebanon"
        },
        {
            "glyph": "🇱🇨",
            "name": "Flag: st. lucia",
            "keywords": "st_lucia"
        },
        {
            "glyph": "🇱🇮",
            "name": "Flag: liechtenstein",
            "keywords": "liechtenstein"
        },
        {
            "glyph": "🇱🇰",
            "name": "Flag: sri lanka",
            "keywords": "sri_lanka"
        },
        {
            "glyph": "🇱🇷",
            "name": "Flag: liberia",
            "keywords": "liberia"
        },
        {
            "glyph": "🇱🇸",
            "name": "Flag: lesotho",
            "keywords": "lesotho"
        },
        {
            "glyph": "🇱🇹",
            "name": "Flag: lithuania",
            "keywords": "lithuania"
        },
        {
            "glyph": "🇱🇺",
            "name": "Flag: luxembourg",
            "keywords": "luxembourg"
        },
        {
            "glyph": "🇱🇻",
            "name": "Flag: latvia",
            "keywords": "latvia"
        },
        {
            "glyph": "🇱🇾",
            "name": "Flag: libya",
            "keywords": "libya"
        },
        {
            "glyph": "🇲🇦",
            "name": "Flag: morocco",
            "keywords": "morocco"
        },
        {
            "glyph": "🇲🇨",
            "name": "Flag: monaco",
            "keywords": "monaco"
        },
        {
            "glyph": "🇲🇩",
            "name": "Flag: moldova",
            "keywords": "moldova"
        },
        {
            "glyph": "🇲🇪",
            "name": "Flag: montenegro",
            "keywords": "montenegro"
        },
        {
            "glyph": "🇲🇫",
            "name": "Flag: st. martin",
            "keywords": "st_martin"
        },
        {
            "glyph": "🇲🇬",
            "name": "Flag: madagascar",
            "keywords": "madagascar"
        },
        {
            "glyph": "🇲🇭",
            "name": "Flag: marshall islands",
            "keywords": "marshall_islands"
        },
        {
            "glyph": "🇲🇰",
            "name": "Flag: north macedonia",
            "keywords": "macedonia"
        },
        {
            "glyph": "🇲🇱",
            "name": "Flag: mali",
            "keywords": "mali"
        },
        {
            "glyph": "🇲🇲",
            "name": "Flag: myanmar (burma)",
            "keywords": "myanmar burma"
        },
        {
            "glyph": "🇲🇳",
            "name": "Flag: mongolia",
            "keywords": "mongolia"
        },
        {
            "glyph": "🇲🇴",
            "name": "Flag: macao sar china",
            "keywords": "macau"
        },
        {
            "glyph": "🇲🇵",
            "name": "Flag: northern mariana islands",
            "keywords": "northern_mariana_islands"
        },
        {
            "glyph": "🇲🇶",
            "name": "Flag: martinique",
            "keywords": "martinique"
        },
        {
            "glyph": "🇲🇷",
            "name": "Flag: mauritania",
            "keywords": "mauritania"
        },
        {
            "glyph": "🇲🇸",
            "name": "Flag: montserrat",
            "keywords": "montserrat"
        },
        {
            "glyph": "🇲🇹",
            "name": "Flag: malta",
            "keywords": "malta"
        },
        {
            "glyph": "🇲🇺",
            "name": "Flag: mauritius",
            "keywords": "mauritius"
        },
        {
            "glyph": "🇲🇻",
            "name": "Flag: maldives",
            "keywords": "maldives"
        },
        {
            "glyph": "🇲🇼",
            "name": "Flag: malawi",
            "keywords": "malawi"
        },
        {
            "glyph": "🇲🇽",
            "name": "Flag: mexico",
            "keywords": "mexico"
        },
        {
            "glyph": "🇲🇾",
            "name": "Flag: malaysia",
            "keywords": "malaysia"
        },
        {
            "glyph": "🇲🇿",
            "name": "Flag: mozambique",
            "keywords": "mozambique"
        },
        {
            "glyph": "🇳🇦",
            "name": "Flag: namibia",
            "keywords": "namibia"
        },
        {
            "glyph": "🇳🇨",
            "name": "Flag: new caledonia",
            "keywords": "new_caledonia"
        },
        {
            "glyph": "🇳🇪",
            "name": "Flag: niger",
            "keywords": "niger"
        },
        {
            "glyph": "🇳🇫",
            "name": "Flag: norfolk island",
            "keywords": "norfolk_island"
        },
        {
            "glyph": "🇳🇬",
            "name": "Flag: nigeria",
            "keywords": "nigeria"
        },
        {
            "glyph": "🇳🇮",
            "name": "Flag: nicaragua",
            "keywords": "nicaragua"
        },
        {
            "glyph": "🇳🇱",
            "name": "Flag: netherlands",
            "keywords": "netherlands"
        },
        {
            "glyph": "🇳🇴",
            "name": "Flag: norway",
            "keywords": "norway"
        },
        {
            "glyph": "🇳🇵",
            "name": "Flag: nepal",
            "keywords": "nepal"
        },
        {
            "glyph": "🇳🇷",
            "name": "Flag: nauru",
            "keywords": "nauru"
        },
        {
            "glyph": "🇳🇺",
            "name": "Flag: niue",
            "keywords": "niue"
        },
        {
            "glyph": "🇳🇿",
            "name": "Flag: new zealand",
            "keywords": "new_zealand"
        },
        {
            "glyph": "🇴🇲",
            "name": "Flag: oman",
            "keywords": "oman"
        },
        {
            "glyph": "🇵🇦",
            "name": "Flag: panama",
            "keywords": "panama"
        },
        {
            "glyph": "🇵🇪",
            "name": "Flag: peru",
            "keywords": "peru"
        },
        {
            "glyph": "🇵🇫",
            "name": "Flag: french polynesia",
            "keywords": "french_polynesia"
        },
        {
            "glyph": "🇵🇬",
            "name": "Flag: papua new guinea",
            "keywords": "papua_new_guinea"
        },
        {
            "glyph": "🇵🇭",
            "name": "Flag: philippines",
            "keywords": "philippines"
        },
        {
            "glyph": "🇵🇰",
            "name": "Flag: pakistan",
            "keywords": "pakistan"
        },
        {
            "glyph": "🇵🇱",
            "name": "Flag: poland",
            "keywords": "poland"
        },
        {
            "glyph": "🇵🇲",
            "name": "Flag: st. pierre & miquelon",
            "keywords": "st_pierre_miquelon"
        },
        {
            "glyph": "🇵🇳",
            "name": "Flag: pitcairn islands",
            "keywords": "pitcairn_islands"
        },
        {
            "glyph": "🇵🇷",
            "name": "Flag: puerto rico",
            "keywords": "puerto_rico"
        },
        {
            "glyph": "🇵🇸",
            "name": "Flag: palestinian territories",
            "keywords": "palestinian_territories"
        },
        {
            "glyph": "🇵🇹",
            "name": "Flag: portugal",
            "keywords": "portugal"
        },
        {
            "glyph": "🇵🇼",
            "name": "Flag: palau",
            "keywords": "palau"
        },
        {
            "glyph": "🇵🇾",
            "name": "Flag: paraguay",
            "keywords": "paraguay"
        },
        {
            "glyph": "🇶🇦",
            "name": "Flag: qatar",
            "keywords": "qatar"
        },
        {
            "glyph": "🇷🇪",
            "name": "Flag: réunion",
            "keywords": "reunion"
        },
        {
            "glyph": "🇷🇴",
            "name": "Flag: romania",
            "keywords": "romania"
        },
        {
            "glyph": "🇷🇸",
            "name": "Flag: serbia",
            "keywords": "serbia"
        },
        {
            "glyph": "🇷🇺",
            "name": "Flag: russia",
            "keywords": "ru russia"
        },
        {
            "glyph": "🇷🇼",
            "name": "Flag: rwanda",
            "keywords": "rwanda"
        },
        {
            "glyph": "🇸🇦",
            "name": "Flag: saudi arabia",
            "keywords": "saudi_arabia"
        },
        {
            "glyph": "🇸🇧",
            "name": "Flag: solomon islands",
            "keywords": "solomon_islands"
        },
        {
            "glyph": "🇸🇨",
            "name": "Flag: seychelles",
            "keywords": "seychelles"
        },
        {
            "glyph": "🇸🇩",
            "name": "Flag: sudan",
            "keywords": "sudan"
        },
        {
            "glyph": "🇸🇪",
            "name": "Flag: sweden",
            "keywords": "sweden"
        },
        {
            "glyph": "🇸🇬",
            "name": "Flag: singapore",
            "keywords": "singapore"
        },
        {
            "glyph": "🇸🇭",
            "name": "Flag: st. helena",
            "keywords": "st_helena"
        },
        {
            "glyph": "🇸🇮",
            "name": "Flag: slovenia",
            "keywords": "slovenia"
        },
        {
            "glyph": "🇸🇯",
            "name": "Flag: svalbard & jan mayen",
            "keywords": "svalbard_jan_mayen"
        },
        {
            "glyph": "🇸🇰",
            "name": "Flag: slovakia",
            "keywords": "slovakia"
        },
        {
            "glyph": "🇸🇱",
            "name": "Flag: sierra leone",
            "keywords": "sierra_leone"
        },
        {
            "glyph": "🇸🇲",
            "name": "Flag: san marino",
            "keywords": "san_marino"
        },
        {
            "glyph": "🇸🇳",
            "name": "Flag: senegal",
            "keywords": "senegal"
        },
        {
            "glyph": "🇸🇴",
            "name": "Flag: somalia",
            "keywords": "somalia"
        },
        {
            "glyph": "🇸🇷",
            "name": "Flag: suriname",
            "keywords": "suriname"
        },
        {
            "glyph": "🇸🇸",
            "name": "Flag: south sudan",
            "keywords": "south_sudan"
        },
        {
            "glyph": "🇸🇹",
            "name": "Flag: são tomé & príncipe",
            "keywords": "sao_tome_principe"
        },
        {
            "glyph": "🇸🇻",
            "name": "Flag: el salvador",
            "keywords": "el_salvador"
        },
        {
            "glyph": "🇸🇽",
            "name": "Flag: sint maarten",
            "keywords": "sint_maarten"
        },
        {
            "glyph": "🇸🇾",
            "name": "Flag: syria",
            "keywords": "syria"
        },
        {
            "glyph": "🇸🇿",
            "name": "Flag: eswatini",
            "keywords": "swaziland"
        },
        {
            "glyph": "🇹🇦",
            "name": "Flag: tristan da cunha",
            "keywords": "tristan_da_cunha"
        },
        {
            "glyph": "🇹🇨",
            "name": "Flag: turks & caicos islands",
            "keywords": "turks_caicos_islands"
        },
        {
            "glyph": "🇹🇩",
            "name": "Flag: chad",
            "keywords": "chad"
        },
        {
            "glyph": "🇹🇫",
            "name": "Flag: french southern territories",
            "keywords": "french_southern_territories"
        },
        {
            "glyph": "🇹🇬",
            "name": "Flag: togo",
            "keywords": "togo"
        },
        {
            "glyph": "🇹🇭",
            "name": "Flag: thailand",
            "keywords": "thailand"
        },
        {
            "glyph": "🇹🇯",
            "name": "Flag: tajikistan",
            "keywords": "tajikistan"
        },
        {
            "glyph": "🇹🇰",
            "name": "Flag: tokelau",
            "keywords": "tokelau"
        },
        {
            "glyph": "🇹🇱",
            "name": "Flag: timor-leste",
            "keywords": "timor_leste"
        },
        {
            "glyph": "🇹🇲",
            "name": "Flag: turkmenistan",
            "keywords": "turkmenistan"
        },
        {
            "glyph": "🇹🇳",
            "name": "Flag: tunisia",
            "keywords": "tunisia"
        },
        {
            "glyph": "🇹🇴",
            "name": "Flag: tonga",
            "keywords": "tonga"
        },
        {
            "glyph": "🇹🇷",
            "name": "Flag: turkey",
            "keywords": "tr turkey"
        },
        {
            "glyph": "🇹🇹",
            "name": "Flag: trinidad & tobago",
            "keywords": "trinidad_tobago"
        },
        {
            "glyph": "🇹🇻",
            "name": "Flag: tuvalu",
            "keywords": "tuvalu"
        },
        {
            "glyph": "🇹🇼",
            "name": "Flag: taiwan",
            "keywords": "taiwan"
        },
        {
            "glyph": "🇹🇿",
            "name": "Flag: tanzania",
            "keywords": "tanzania"
        },
        {
            "glyph": "🇺🇦",
            "name": "Flag: ukraine",
            "keywords": "ukraine"
        },
        {
            "glyph": "🇺🇬",
            "name": "Flag: uganda",
            "keywords": "uganda"
        },
        {
            "glyph": "🇺🇲",
            "name": "Flag: u.s. outlying islands",
            "keywords": "us_outlying_islands"
        },
        {
            "glyph": "🇺🇳",
            "name": "Flag: united nations",
            "keywords": "united_nations"
        },
        {
            "glyph": "🇺🇸",
            "name": "Flag: united states",
            "keywords": "us flag united america"
        },
        {
            "glyph": "🇺🇾",
            "name": "Flag: uruguay",
            "keywords": "uruguay"
        },
        {
            "glyph": "🇺🇿",
            "name": "Flag: uzbekistan",
            "keywords": "uzbekistan"
        },
        {
            "glyph": "🇻🇦",
            "name": "Flag: vatican city",
            "keywords": "vatican_city"
        },
        {
            "glyph": "🇻🇨",
            "name": "Flag: st. vincent & grenadines",
            "keywords": "st_vincent_grenadines"
        },
        {
            "glyph": "🇻🇪",
            "name": "Flag: venezuela",
            "keywords": "venezuela"
        },
        {
            "glyph": "🇻🇬",
            "name": "Flag: british virgin islands",
            "keywords": "british_virgin_islands"
        },
        {
            "glyph": "🇻🇮",
            "name": "Flag: u.s. virgin islands",
            "keywords": "us_virgin_islands"
        },
        {
            "glyph": "🇻🇳",
            "name": "Flag: vietnam",
            "keywords": "vietnam"
        },
        {
            "glyph": "🇻🇺",
            "name": "Flag: vanuatu",
            "keywords": "vanuatu"
        },
        {
            "glyph": "🇼🇫",
            "name": "Flag: wallis & futuna",
            "keywords": "wallis_futuna"
        },
        {
            "glyph": "🇼🇸",
            "name": "Flag: samoa",
            "keywords": "samoa"
        },
        {
            "glyph": "🇽🇰",
            "name": "Flag: kosovo",
            "keywords": "kosovo"
        },
        {
            "glyph": "🇾🇪",
            "name": "Flag: yemen",
            "keywords": "yemen"
        },
        {
            "glyph": "🇾🇹",
            "name": "Flag: mayotte",
            "keywords": "mayotte"
        },
        {
            "glyph": "🇿🇦",
            "name": "Flag: south africa",
            "keywords": "south_africa"
        },
        {
            "glyph": "🇿🇲",
            "name": "Flag: zambia",
            "keywords": "zambia"
        },
        {
            "glyph": "🇿🇼",
            "name": "Flag: zimbabwe",
            "keywords": "zimbabwe"
        },
        {
            "glyph": "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
            "name": "Flag: england",
            "keywords": "england"
        },
        {
            "glyph": "🏴󠁧󠁢󠁳󠁣󠁴󠁿",
            "name": "Flag: scotland",
            "keywords": "scotland"
        },
        {
            "glyph": "🏴󠁧󠁢󠁷󠁬󠁳󠁿",
            "name": "Flag: wales",
            "keywords": "wales"
        }
    ]
    property string query: ""
    readonly property var results: {
        var term = searchTerm;
        var matches = [];
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i];
            var haystack = (entry.name + " " + entry.keywords).toLowerCase();
            if (term === "" || haystack.indexOf(term) !== -1 || entry.glyph === term)
                matches.push({
                    "type": "emoji",
                    "data": entry
                });

            if (matches.length >= 40)
                break;
        }
        return matches;
    }
    readonly property string searchTerm: {
        if (!query.toLowerCase().startsWith("e "))
            return "";

        return query.substring(2).trim().toLowerCase();
    }

    function copy(entry) {
        if (entry && entry.glyph)
            Quickshell.execDetached(["wl-copy", entry.glyph]);
    }
}
