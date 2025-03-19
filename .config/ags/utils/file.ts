import { GLib } from "astal"

const fileExists = (path: string) =>
	GLib.file_test(path, GLib.FileTest.EXISTS)

export { fileExists }
