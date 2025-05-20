import { SearchProvider, SearchProviderWidget } from "./searchprovider"

export default function GnomeCalculator() {
	const max_items = 2
	const CalculatorSearchProvider = new SearchProvider(
		"org.gnome.Calculator.SearchProvider",
		"/org/gnome/Calculator/SearchProvider",
		"org.gnome.Shell.SearchProvider2"
	)
	return new SearchProviderWidget("Calculator", "org.gnome.Calculator", max_items, CalculatorSearchProvider)
}