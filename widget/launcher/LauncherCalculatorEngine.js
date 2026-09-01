var functionNames = [
    "abs",
    "acos",
    "asin",
    "atan",
    "atan2",
    "cbrt",
    "ceil",
    "cos",
    "exp",
    "floor",
    "hypot",
    "log",
    "log10",
    "log2",
    "max",
    "min",
    "pow",
    "round",
    "sin",
    "sqrt",
    "tan",
];
var unitMap = null;

function calculatorError(kind, code, token) {
    return {
        calculatorError: true,
        kind: kind,
        code: code,
        token: token || "",
    };
}

function throwCalculatorError(kind, code, token) {
    throw calculatorError(kind, code, token);
}

function normalizeSource(source) {
    return String(source || "")
        .replace(/[−–—]/g, "-")
        .replace(/×/g, "*")
        .replace(/÷/g, "/")
        .replace(/π/g, "pi")
        .replace(/√/g, "sqrt ")
        .replace(/\b[xX]\b/g, "*")
        .replace(/([0-9.)!%])\s*[xX]\s*(?=[0-9.(a-zA-Z_])/g, "$1*")
        .trim();
}

function registerUnit(map, category, symbol, factor, offset, aliases) {
    var unit = {
        category: category,
        factor: factor,
        offset: offset || 0,
        symbol: symbol,
    };
    for (var index = 0; index < aliases.length; ++index)
        map[String(aliases[index]).toLowerCase()] = unit;
}

function units() {
    if (unitMap) return unitMap;

    var map = {};
    registerUnit(map, "length", "mm", 0.001, 0, [
        "mm",
        "millimeter",
        "millimeters",
        "millimetre",
        "millimetres",
    ]);
    registerUnit(map, "length", "cm", 0.01, 0, [
        "cm",
        "centimeter",
        "centimeters",
        "centimetre",
        "centimetres",
    ]);
    registerUnit(map, "length", "m", 1, 0, [
        "m",
        "meter",
        "meters",
        "metre",
        "metres",
    ]);
    registerUnit(map, "length", "km", 1000, 0, [
        "km",
        "kilometer",
        "kilometers",
        "kilometre",
        "kilometres",
    ]);
    registerUnit(map, "length", "in", 0.0254, 0, ["in", "inch", "inches"]);
    registerUnit(map, "length", "ft", 0.3048, 0, ["ft", "foot", "feet"]);
    registerUnit(map, "length", "yd", 0.9144, 0, ["yd", "yard", "yards"]);
    registerUnit(map, "length", "mi", 1609.344, 0, ["mi", "mile", "miles"]);

    registerUnit(map, "mass", "mg", 0.000001, 0, [
        "mg",
        "milligram",
        "milligrams",
    ]);
    registerUnit(map, "mass", "g", 0.001, 0, ["g", "gram", "grams"]);
    registerUnit(map, "mass", "kg", 1, 0, ["kg", "kilogram", "kilograms"]);
    registerUnit(map, "mass", "oz", 0.028349523125, 0, [
        "oz",
        "ounce",
        "ounces",
    ]);
    registerUnit(map, "mass", "lb", 0.45359237, 0, [
        "lb",
        "lbs",
        "pound",
        "pounds",
    ]);
    registerUnit(map, "mass", "t", 1000, 0, [
        "t",
        "tonne",
        "tonnes",
        "metricton",
        "metrictons",
    ]);

    registerUnit(map, "time", "ms", 0.001, 0, [
        "ms",
        "millisecond",
        "milliseconds",
    ]);
    registerUnit(map, "time", "s", 1, 0, [
        "s",
        "sec",
        "secs",
        "second",
        "seconds",
    ]);
    registerUnit(map, "time", "min", 60, 0, [
        "min",
        "mins",
        "minute",
        "minutes",
    ]);
    registerUnit(map, "time", "h", 3600, 0, [
        "h",
        "hr",
        "hrs",
        "hour",
        "hours",
    ]);
    registerUnit(map, "time", "day", 86400, 0, ["d", "day", "days"]);
    registerUnit(map, "time", "week", 604800, 0, ["w", "wk", "week", "weeks"]);

    registerUnit(map, "storage", "B", 1, 0, ["b", "byte", "bytes"]);
    registerUnit(map, "storage", "KB", 1000, 0, [
        "kb",
        "kilobyte",
        "kilobytes",
    ]);
    registerUnit(map, "storage", "MB", 1000000, 0, [
        "mb",
        "megabyte",
        "megabytes",
    ]);
    registerUnit(map, "storage", "GB", 1000000000, 0, [
        "gb",
        "gigabyte",
        "gigabytes",
    ]);
    registerUnit(map, "storage", "TB", 1000000000000, 0, [
        "tb",
        "terabyte",
        "terabytes",
    ]);
    registerUnit(map, "storage", "KiB", 1024, 0, [
        "kib",
        "kibibyte",
        "kibibytes",
    ]);
    registerUnit(map, "storage", "MiB", 1048576, 0, [
        "mib",
        "mebibyte",
        "mebibytes",
    ]);
    registerUnit(map, "storage", "GiB", 1073741824, 0, [
        "gib",
        "gibibyte",
        "gibibytes",
    ]);
    registerUnit(map, "storage", "TiB", 1099511627776, 0, [
        "tib",
        "tebibyte",
        "tebibytes",
    ]);

    registerUnit(map, "temperature", "°C", 1, 0, ["c", "°c", "celsius"]);
    registerUnit(map, "temperature", "°F", 5 / 9, -32, [
        "f",
        "°f",
        "fahrenheit",
    ]);
    registerUnit(map, "temperature", "K", 1, -273.15, ["k", "kelvin"]);

    registerUnit(map, "angle", "deg", Math.PI / 180, 0, [
        "deg",
        "degree",
        "degrees",
    ]);
    registerUnit(map, "angle", "rad", 1, 0, ["rad", "radian", "radians"]);

    unitMap = map;
    return unitMap;
}

function normalizeUnitName(name) {
    return String(name || "")
        .toLowerCase()
        .replace(/\./g, "");
}

function unitForName(name) {
    return units()[normalizeUnitName(name)] || null;
}

function isUnitPrefix(name) {
    var prefix = normalizeUnitName(name);
    if (prefix === "") return false;
    var map = units();
    for (var key in map) {
        if (key.indexOf(prefix) === 0) return true;
    }
    return false;
}

function formatNumber(value) {
    if (!isFinite(value)) return "";
    if (Math.abs(value) < 1e-14) value = 0;

    var absolute = Math.abs(value);
    if (absolute !== 0 && (absolute >= 1e12 || absolute < 1e-9)) {
        var exponential = value.toExponential(10);
        exponential = exponential
            .replace(/(\.\d*?[1-9])0+e/, "$1e")
            .replace(/\.0+e/, "e");
        return exponential;
    }

    return String(Number(value.toPrecision(12)));
}

function tokenize(source) {
    var tokens = [];
    var index = 0;
    while (index < source.length) {
        var character = source.charAt(index);
        if (/\s/.test(character)) {
            ++index;
            continue;
        }

        if (/\d/.test(character) || character === ".") {
            var start = index;
            var sawDigit = false;
            while (index < source.length && /\d/.test(source.charAt(index))) {
                sawDigit = true;
                ++index;
            }
            if (source.charAt(index) === ".") {
                ++index;
                while (
                    index < source.length &&
                    /\d/.test(source.charAt(index))
                ) {
                    sawDigit = true;
                    ++index;
                }
            }
            if (!sawDigit)
                throwCalculatorError("error", "invalid_number", character);

            if (
                (source.charAt(index) === "e" ||
                    source.charAt(index) === "E") &&
                /[+\-\d]/.test(source.charAt(index + 1))
            ) {
                ++index;
                if (
                    source.charAt(index) === "+" ||
                    source.charAt(index) === "-"
                )
                    ++index;
                var exponentStart = index;
                while (index < source.length && /\d/.test(source.charAt(index)))
                    ++index;
                if (exponentStart === index)
                    throwCalculatorError("incomplete", "incomplete_expression");
            }

            var numberText = source.substring(start, index);
            var numberValue = Number(numberText);
            if (!isFinite(numberValue))
                throwCalculatorError("error", "invalid_number", numberText);
            tokens.push({
                type: "number",
                value: numberValue,
                text: numberText,
            });
            continue;
        }

        if (/[a-zA-Z_]/.test(character)) {
            var identifierStart = index;
            while (
                index < source.length &&
                /[a-zA-Z0-9_]/.test(source.charAt(index))
            )
                ++index;
            tokens.push({
                type: "identifier",
                text: source.substring(identifierStart, index).toLowerCase(),
            });
            continue;
        }

        if (character === "*" && source.charAt(index + 1) === "*") {
            tokens.push({
                type: "operator",
                text: "^",
            });
            index += 2;
            continue;
        }
        if ("+-*/^%!(),".indexOf(character) !== -1) {
            var type =
                character === "("
                    ? "leftParen"
                    : character === ")"
                      ? "rightParen"
                      : character === ","
                        ? "comma"
                        : "operator";
            tokens.push({
                type: type,
                text: character,
            });
            ++index;
            continue;
        }

        throwCalculatorError("error", "unknown_token", character);
    }
    tokens.push({
        type: "eof",
        text: "",
    });
    return tokens;
}

function Parser(tokens, angleMode, previousAnswer) {
    this.tokens = tokens;
    this.index = 0;
    this.angleMode = angleMode === "deg" ? "deg" : "rad";
    this.previousAnswer = previousAnswer;
}

Parser.prototype.current = function () {
    return this.tokens[this.index];
};

Parser.prototype.advance = function () {
    var token = this.current();
    if (token.type !== "eof") ++this.index;
    return token;
};

Parser.prototype.matchOperator = function (operator) {
    var token = this.current();
    if (token.type === "operator" && token.text === operator) {
        this.advance();
        return true;
    }
    return false;
};

Parser.prototype.matchIdentifier = function (identifier) {
    var token = this.current();
    if (token.type === "identifier" && token.text === identifier) {
        this.advance();
        return true;
    }
    return false;
};

Parser.prototype.ensureFinite = function (value) {
    if (!isFinite(value)) throwCalculatorError("error", "domain_error");
    return value;
};

Parser.prototype.parse = function () {
    var value = this.parseAdditive();
    if (this.current().type !== "eof")
        throwCalculatorError("error", "unexpected_token", this.current().text);
    return this.ensureFinite(value);
};

Parser.prototype.parseAdditive = function () {
    var value = this.parseMultiplicative();
    while (true) {
        if (this.matchOperator("+"))
            value = this.ensureFinite(value + this.parseMultiplicative());
        else if (this.matchOperator("-"))
            value = this.ensureFinite(value - this.parseMultiplicative());
        else return value;
    }
};

Parser.prototype.canStartImplicitValue = function (token) {
    if (token.type === "number" || token.type === "leftParen") return true;
    return (
        token.type === "identifier" &&
        token.text !== "of" &&
        token.text !== "mod"
    );
};

Parser.prototype.parseMultiplicative = function () {
    var value = this.parseUnary();
    while (true) {
        if (this.matchOperator("*")) {
            value = this.ensureFinite(value * this.parseUnary());
        } else if (this.matchOperator("/")) {
            var divisor = this.parseUnary();
            if (divisor === 0)
                throwCalculatorError("error", "division_by_zero");
            value = this.ensureFinite(value / divisor);
        } else if (this.matchIdentifier("mod")) {
            var modulus = this.parseUnary();
            if (modulus === 0)
                throwCalculatorError("error", "division_by_zero");
            value = this.ensureFinite(value % modulus);
        } else if (this.matchIdentifier("x")) {
            value = this.ensureFinite(value * this.parseUnary());
        } else if (this.matchIdentifier("of")) {
            value = this.ensureFinite(value * this.parseUnary());
        } else if (this.canStartImplicitValue(this.current())) {
            value = this.ensureFinite(value * this.parseUnary());
        } else {
            return value;
        }
    }
};

Parser.prototype.parseUnary = function () {
    if (this.matchOperator("+")) return this.parseUnary();
    if (this.matchOperator("-")) return -this.parseUnary();
    return this.parsePower();
};

Parser.prototype.parsePower = function () {
    var value = this.parsePostfix();
    if (this.matchOperator("^"))
        value = this.ensureFinite(Math.pow(value, this.parseUnary()));
    return value;
};

Parser.prototype.factorial = function (value) {
    if (value < 0 || Math.floor(value) !== value || value > 170)
        throwCalculatorError("error", "invalid_factorial");
    var result = 1;
    for (var index = 2; index <= value; ++index) result *= index;
    return result;
};

Parser.prototype.parsePostfix = function () {
    var value = this.parsePrimary();
    while (true) {
        if (this.matchOperator("!")) value = this.factorial(value);
        else if (this.matchOperator("%")) value /= 100;
        else return value;
    }
};

Parser.prototype.isFunction = function (name) {
    return functionNames.indexOf(name) !== -1;
};

Parser.prototype.isKnownPrefix = function (name) {
    var identifiers = functionNames.concat(["ans", "mod", "of", "pi"]);
    for (var index = 0; index < identifiers.length; ++index) {
        if (identifiers[index].indexOf(name) === 0) return true;
    }
    return isUnitPrefix(name);
};

Parser.prototype.parseArguments = function () {
    var argumentsList = [];
    if (this.current().type === "rightParen") {
        this.advance();
        return argumentsList;
    }
    while (true) {
        if (this.current().type === "eof")
            throwCalculatorError("incomplete", "incomplete_expression");
        argumentsList.push(this.parseAdditive());
        if (this.current().type === "comma") {
            this.advance();
            if (
                this.current().type === "eof" ||
                this.current().type === "rightParen"
            )
                throwCalculatorError("incomplete", "incomplete_expression");
            continue;
        }
        if (this.current().type !== "rightParen") {
            if (this.current().type === "eof")
                throwCalculatorError("incomplete", "incomplete_expression");
            throwCalculatorError(
                "error",
                "unexpected_token",
                this.current().text,
            );
        }
        this.advance();
        return argumentsList;
    }
};

Parser.prototype.angleInput = function (value) {
    return this.angleMode === "deg" ? (value * Math.PI) / 180 : value;
};

Parser.prototype.angleOutput = function (value) {
    return this.angleMode === "deg" ? (value * 180) / Math.PI : value;
};

Parser.prototype.callFunction = function (name, args) {
    var oneArgument = [
        "abs",
        "acos",
        "asin",
        "atan",
        "cbrt",
        "ceil",
        "cos",
        "exp",
        "floor",
        "log",
        "log10",
        "log2",
        "round",
        "sin",
        "sqrt",
        "tan",
    ];
    if (oneArgument.indexOf(name) !== -1 && args.length !== 1)
        throwCalculatorError("error", "invalid_arguments", name);
    if ((name === "atan2" || name === "pow") && args.length !== 2)
        throwCalculatorError("error", "invalid_arguments", name);
    if ((name === "min" || name === "max") && args.length < 1)
        throwCalculatorError("error", "invalid_arguments", name);
    if (name === "hypot" && args.length < 2)
        throwCalculatorError("error", "invalid_arguments", name);

    var result = 0;
    switch (name) {
        case "abs":
            result = Math.abs(args[0]);
            break;
        case "acos":
            result = this.angleOutput(Math.acos(args[0]));
            break;
        case "asin":
            result = this.angleOutput(Math.asin(args[0]));
            break;
        case "atan":
            result = this.angleOutput(Math.atan(args[0]));
            break;
        case "atan2":
            result = this.angleOutput(Math.atan2(args[0], args[1]));
            break;
        case "cbrt":
            result = Math.cbrt
                ? Math.cbrt(args[0])
                : args[0] < 0
                  ? -Math.pow(-args[0], 1 / 3)
                  : Math.pow(args[0], 1 / 3);
            break;
        case "ceil":
            result = Math.ceil(args[0]);
            break;
        case "cos":
            result = Math.cos(this.angleInput(args[0]));
            break;
        case "exp":
            result = Math.exp(args[0]);
            break;
        case "floor":
            result = Math.floor(args[0]);
            break;
        case "hypot":
            var sum = 0;
            for (var hypotIndex = 0; hypotIndex < args.length; ++hypotIndex)
                sum += args[hypotIndex] * args[hypotIndex];
            result = Math.sqrt(sum);
            break;
        case "log":
            result = Math.log(args[0]);
            break;
        case "log10":
            result = Math.log10
                ? Math.log10(args[0])
                : Math.log(args[0]) / Math.LN10;
            break;
        case "log2":
            result = Math.log2
                ? Math.log2(args[0])
                : Math.log(args[0]) / Math.LN2;
            break;
        case "max":
            result = Math.max.apply(Math, args);
            break;
        case "min":
            result = Math.min.apply(Math, args);
            break;
        case "pow":
            result = Math.pow(args[0], args[1]);
            break;
        case "round":
            result = Math.round(args[0]);
            break;
        case "sin":
            result = Math.sin(this.angleInput(args[0]));
            break;
        case "sqrt":
            result = Math.sqrt(args[0]);
            break;
        case "tan":
            result = Math.tan(this.angleInput(args[0]));
            break;
        default:
            throwCalculatorError("error", "unknown_identifier", name);
    }
    return this.ensureFinite(result);
};

Parser.prototype.parsePrimary = function () {
    var token = this.current();
    if (token.type === "eof")
        throwCalculatorError("incomplete", "incomplete_expression");
    if (token.type === "number") {
        this.advance();
        return token.value;
    }
    if (token.type === "leftParen") {
        this.advance();
        var parenthesized = this.parseAdditive();
        if (this.current().type === "eof")
            throwCalculatorError("incomplete", "incomplete_expression");
        if (this.current().type !== "rightParen")
            throwCalculatorError(
                "error",
                "unexpected_token",
                this.current().text,
            );
        this.advance();
        return parenthesized;
    }
    if (token.type === "identifier") {
        this.advance();
        var name = token.text;
        if (name === "pi") return Math.PI;
        if (name === "e") return Math.E;
        if (name === "ans") {
            if (
                this.previousAnswer === null ||
                this.previousAnswer === undefined ||
                !isFinite(Number(this.previousAnswer))
            )
                throwCalculatorError("error", "missing_answer");
            return Number(this.previousAnswer);
        }
        if (this.isFunction(name)) {
            var args = [];
            if (this.current().type === "leftParen") {
                this.advance();
                args = this.parseArguments();
            } else {
                var oneArgumentFunctions = [
                    "abs",
                    "acos",
                    "asin",
                    "atan",
                    "cbrt",
                    "ceil",
                    "cos",
                    "exp",
                    "floor",
                    "log",
                    "log10",
                    "log2",
                    "round",
                    "sin",
                    "sqrt",
                    "tan",
                ];
                if (oneArgumentFunctions.indexOf(name) === -1)
                    throwCalculatorError("incomplete", "incomplete_expression");
                args = [this.parseUnary()];
            }
            return this.callFunction(name, args);
        }
        if (this.isKnownPrefix(name))
            throwCalculatorError("incomplete", "incomplete_expression", name);
        throwCalculatorError("error", "unknown_identifier", name);
    }
    throwCalculatorError("error", "unexpected_token", token.text);
};

function arithmeticResult(source, angleMode, previousAnswer) {
    try {
        var parser = new Parser(tokenize(source), angleMode, previousAnswer);
        var value = parser.parse();
        return {
            status: "result",
            value: value,
            display: formatNumber(value),
            detail: "",
        };
    } catch (error) {
        if (error && error.calculatorError) {
            return {
                status: error.kind,
                code: error.code,
                token: error.token || "",
                display: "",
                detail: "",
            };
        }
        return {
            status: "error",
            code: "invalid_expression",
            token: "",
            display: "",
            detail: "",
        };
    }
}

function convertValue(value, sourceUnit, targetUnit) {
    var baseValue = (value + sourceUnit.offset) * sourceUnit.factor;
    return baseValue / targetUnit.factor - targetUnit.offset;
}

function conversionResult(source, angleMode, previousAnswer) {
    var compact = source.replace(/\s+/g, " ").trim();
    if (/\bto\s*$/i.test(compact)) {
        return {
            status: "incomplete",
            code: "incomplete_expression",
            display: "",
            detail: "",
        };
    }

    var match = /^(.*?)\s+([a-zA-Z°]+)\s+to\s+([a-zA-Z°]+)$/i.exec(compact);
    if (!match) {
        var pending = /^(.*?)\s+([a-zA-Z°]+)$/i.exec(compact);
        if (pending && unitForName(pending[2])) {
            return {
                status: "incomplete",
                code: "incomplete_conversion",
                display: "",
                detail: "",
            };
        }
        return null;
    }

    var sourceUnit = unitForName(match[2]);
    var targetUnit = unitForName(match[3]);
    if (!sourceUnit || !targetUnit) {
        return {
            status: "error",
            code: "unknown_unit",
            token: !sourceUnit ? match[2] : match[3],
            display: "",
            detail: "",
        };
    }
    if (sourceUnit.category !== targetUnit.category) {
        return {
            status: "error",
            code: "incompatible_units",
            display: "",
            detail: "",
        };
    }

    var input = arithmeticResult(match[1], angleMode, previousAnswer);
    if (input.status !== "result") return input;

    var converted = convertValue(input.value, sourceUnit, targetUnit);
    if (!isFinite(converted)) {
        return {
            status: "error",
            code: "domain_error",
            display: "",
            detail: "",
        };
    }
    return {
        status: "result",
        value: converted,
        display: formatNumber(converted) + " " + targetUnit.symbol,
        detail: sourceUnit.symbol + " → " + targetUnit.symbol,
        conversion: true,
    };
}

function evaluate(source, angleMode, previousAnswer) {
    var normalized = normalizeSource(source);
    if (normalized === "") {
        return {
            status: "empty",
            code: "",
            display: "",
            detail: "",
        };
    }

    var conversion = conversionResult(normalized, angleMode, previousAnswer);
    if (conversion) return conversion;
    return arithmeticResult(normalized, angleMode, previousAnswer);
}
