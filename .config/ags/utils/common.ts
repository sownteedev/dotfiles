const map = <T, U>(array: T[], func: (value: T, index: number) => U): U[] => {
    const newArr: U[] = [];
    for (let i = 0; i < array.length; i++) {
        newArr[i] = func(array[i], i);
    }
    return newArr;
}

export { map };
