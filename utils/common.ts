const map = <T, U>(array: T[], func: (value: T, index: number) => U): U[] => {
	const newArr: U[] = [];
	for (let i = 0; i < array.length; i++) {
		newArr[i] = func(array[i], i);
	}
	return newArr;
}

const find = <T>(array: T[], fn: (value: T, index: number) => boolean): T | undefined => {
	fn = fn || function(value, index) {
		return value
	}

	for (let index = 0; index < array.length; index++) {
		const value = array[index];
		if (fn(value, index)) {
			return value
		}
	}
}

const any = <T>(array: T[], fn: (value: T, index: number) => boolean): boolean => {
	for (let index = 0; index < array.length; index++) {
		const value = array[index];
		if (fn(value, index)) {
			return true
		}
	}
	return false
}

const sanitizeUtf8 = (text: string): string => {
	if (!text) {
		return ""
	}
	const regex = /[\x00-\x1F\x7F]/g;
	return text.replace(regex, "");
}

const truncateText = (text: string, length: number): string => {
	if (!text) {
		return ""
	}
	text = sanitizeUtf8(text)
	if (text.length > length) {
		return text.substring(0, length) + "...";
	}
	return text
}

export { map, find, any, sanitizeUtf8, truncateText };
