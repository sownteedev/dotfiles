import { GLib } from "astal"

const fileExists = (path: string) =>
	GLib.file_test(path, GLib.FileTest.EXISTS)

const isImage = (filename: string): boolean => {
	if (GLib.file_test(filename, GLib.FileTest.EXISTS)) {
		const imgExt = [".png", ".jpg", ".jpeg", ".svg"];
		const filenameLower = filename.toLowerCase();
		for (const ext of imgExt) {
			if (filenameLower.endsWith(ext)) {
				return true;
			}
		}
	}
	return false;
};

export { fileExists, isImage }
