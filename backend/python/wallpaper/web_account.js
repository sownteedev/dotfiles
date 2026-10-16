async function sownteeAccountAction(request) {
    function failure(code, message) {
        return { ok: false, code, message };
    }
    function parseHtml(html) {
        return new DOMParser().parseFromString(html, "text/html");
    }
    async function getPage(path) {
        const response = await fetch(path, { credentials: "same-origin", cache: "no-store", redirect: "error" });
        if (!response.ok)
            throw new Error("request_failed");
        return parseHtml(await response.text());
    }
    function wallhavenAccount(page) {
        if (!/^\/favorites(?:\/\d+)?\/?$/.test(location.pathname))
            return null;
        if (page.querySelector('#userpanel a[href="https://wallhaven.cc/login"]'))
            return null;
        const links = page.querySelectorAll('#userpanel a[href], a[href*="/favorites/"]');
        for (const link of links) {
            const target = new URL(link.getAttribute("href"), "https://wallhaven.cc");
            const match = target.pathname.match(/^\/user\/([^/]+)(?:\/favorites\/\d+)?\/?$/);
            if (target.origin === "https://wallhaven.cc" && match) {
                const username = decodeURIComponent(match[1]);
                return { id: username, label: username };
            }
        }
        return null;
    }
    function collectionList(page) {
        return Array.from(page.querySelectorAll(".collections-list .collection[data-collection-id]")).map(node => {
            const label = node.cloneNode(true);
            label.querySelectorAll("small, i").forEach(child => child.remove());
            return { id: node.getAttribute("data-collection-id"), label: label.textContent.trim() };
        }).filter(item => /^[1-9][0-9]*$/.test(item.id));
    }
    function steamAccount() {
        const identifier = String(globalThis.g_steamID || "");
        if (!/^[0-9]{17}$/.test(identifier))
            return null;
        const label = document.querySelector("#account_pulldown");
        return { id: identifier, label: (label ? label.textContent.trim() : identifier) + " (" + identifier + ")" };
    }
    try {
        const provider = request.provider;
        const expectedOrigin = provider === "wallhaven" ? "https://wallhaven.cc" : "https://steamcommunity.com";
        if (location.origin !== expectedOrigin)
            return failure("wrong_origin", "The account page is not on the expected website.");
        const account = provider === "wallhaven" ? wallhavenAccount(document) : steamAccount();
        if (!account)
            return failure("authentication_required", "Your website session expired or is not signed in. Connect again in Settings > Integrations.");
        if (request.expected_account && account.id !== request.expected_account)
            return failure("account_changed", "The website account changed. Reconnect in Settings before saving anything.");
        if (request.action === "identity" || request.action === "status")
            return { ok: true, account };
        if (provider === "wallhaven") {
            const collections = collectionList(document);
            if (request.action === "collections")
                return { ok: true, items: collections, account };
            if (!["collect", "uncollect"].includes(request.action) || !/^[a-z0-9]{6}$/.test(request.item_id))
                return failure("invalid_request", "Invalid Wallhaven wallpaper identifier.");
            const selected = collections.find(item => item.id === request.collection_id);
            if (request.action === "collect" && !selected)
                return failure("invalid_collection", "Choose a collection belonging to the connected Wallhaven account.");
            const wallpaper = await getPage("/w/" + request.item_id);
            const favorite = wallpaper.querySelector("#fav-button");
            if (!favorite)
                return failure("unsupported_page", "The Wallhaven save controls are unavailable. Reconnect or check the wallpaper on the website.");
            if (request.action === "uncollect" && favorite.classList.contains("add-button"))
                return { ok: true, item_id: request.item_id, collected: false, existing: true, message: "Already removed from Collection." };
            const controls = Array.from(favorite.querySelectorAll("a[href]"));
            if (favorite.matches("a[href]"))
                controls.push(favorite);
            const links = controls.map(link => new URL(link.getAttribute("href"), expectedOrigin));
            const matchesCollection = target => target.origin === expectedOrigin && target.searchParams.get("wallHashid") === request.item_id && target.searchParams.get("collectionId") === selected.id;
            const action = request.action === "uncollect" ? "remove" : "add";
            const endpoint = request.action === "uncollect" ?
                links.find(target => target.origin === expectedOrigin && target.pathname === "/favorites/delete/" + request.item_id) :
                links.find(target => matchesCollection(target) && target.pathname === "/favorites/add");
            if (!endpoint)
                return failure("unsupported_control", "The Wallhaven collection control is not recognized or does not offer this action. No changes were made; check the wallpaper on Wallhaven.");
            const csrf = endpoint.searchParams.get("_token");
            if (!csrf)
                return failure("authentication_required", "The website session is missing its security token. Reconnect your account.");
            const body = new URLSearchParams(endpoint.searchParams);
            const response = await fetch(endpoint.pathname, {
                method: "POST", credentials: "same-origin", redirect: "error",
                headers: { "X-Requested-With": "XMLHttpRequest", "Accept": "application/json" }, body
            });
            if (response.status === 401 || response.status === 419)
                return failure("authentication_required", "Your Wallhaven session expired. Reconnect your account.");
            if (!response.ok)
                return failure(action + "_failed", "Wallhaven did not accept the collection change. Check the website before retrying.");
            const result = await response.json();
            if (result.status !== true && result.status !== 1)
                return failure(action + "_failed", "Wallhaven did not confirm the collection change. No success state was recorded.");
            const verified = await getPage("/w/" + request.item_id);
            const verifiedFavorite = verified.querySelector("#fav-button");
            if (!verifiedFavorite || verifiedFavorite.classList.contains("add-button") !== (request.action === "uncollect"))
                return failure("verification_failed", "Wallhaven accepted the request but its saved state could not be verified. Check the website before retrying.");
            return {
                ok: true,
                item_id: request.item_id,
                collection_id: selected ? selected.id : "",
                collection_label: selected ? selected.label : "",
                collected: request.action !== "uncollect",
                message: request.action === "uncollect" ? "Removed from Collection." : "Saved to " + selected.label + "."
            };
        }
        if (request.action === "subscriptions") {
            const pageNumber = request.page || 1;
            const path = "/profiles/" + account.id + "/myworkshopfiles/";
            let finalUrl = new URL(location.href);
            let page = document;
            if (!/^\/(?:id|profiles)\/[^/]+\/myworkshopfiles\/?$/.test(finalUrl.pathname)
                || finalUrl.searchParams.get("appid") !== "431960"
                || finalUrl.searchParams.get("browsefilter") !== "mysubscriptions"
                || Number(finalUrl.searchParams.get("p") || 1) !== pageNumber) {
                const response = await fetch(path + "?appid=431960&browsefilter=mysubscriptions&numperpage=30&p=" + pageNumber + "&l=english", {
                    credentials: "same-origin", cache: "no-store", redirect: "follow"
                });
                finalUrl = new URL(response.url);
                if (!response.ok || finalUrl.origin !== expectedOrigin)
                    return failure("request_failed", "Could not load Steam subscriptions.");
                page = parseHtml(await response.text());
            }
            if (!page.querySelector("#account_pulldown"))
                return failure("authentication_required", "Your Steam session expired. Reconnect your account.");
            const paging = page.querySelector(".workshopBrowsePagingInfo");
            if (!paging)
                return failure("unsupported_page", "Steam subscription controls are unavailable. Check the website before retrying.");
            const items = [];
            const seen = new Set();
            for (const node of page.querySelectorAll(".workshopItemSubscription")) {
                const identifier = node.id.match(/^Subscription([1-9][0-9]*)$/);
                if (!identifier || seen.has(identifier[1]))
                    continue;
                const itemId = identifier[1];
                const subscribed = node.querySelector('[id="subscribed_' + itemId + '"]');
                const app = node.querySelector(".workshopItemApp");
                const title = node.querySelector(".workshopItemTitle");
                if (!subscribed || !subscribed.classList.contains("toggled") || !app || app.textContent.trim() !== "Wallpaper Engine" || !title)
                    continue;
                const image = node.querySelector(".workshopItemPreviewImage");
                let preview = "";
                if (image) {
                    const url = new URL(image.getAttribute("src") || "", expectedOrigin);
                    if (url.protocol === "https:" && /(^|\.)(steamusercontent\.com|steamstatic\.com|steamuserimages-a\.akamaihd\.net)$/.test(url.hostname)) {
                        url.searchParams.set("imw", "520");
                        url.searchParams.set("imh", "320");
                        preview = url.href;
                    }
                }
                seen.add(itemId);
                items.push({ id: itemId, title: title.textContent.trim(), preview, subscribed: true,
                    accountSubscribed: true, accountSubscriptionKnown: true, downloaded: false,
                    path: "", type: "", nsfw: false, file_size: 0, resolution: "" });
            }
            const range = paging.textContent.match(/([\d,]+)\s*-\s*([\d,]+)\s+of\s+([\d,]+)/i);
            let hasNext = range ? Number(range[2].replace(/,/g, "")) < Number(range[3].replace(/,/g, "")) : false;
            for (const link of page.querySelectorAll(".workshopBrowsePagingControls a[href]")) {
                const target = new URL(link.getAttribute("href"), expectedOrigin);
                if (target.origin === expectedOrigin && target.pathname.replace(/\/$/, "") === finalUrl.pathname.replace(/\/$/, "") && Number(target.searchParams.get("p")) > pageNumber)
                    hasNext = true;
            }
            return { ok: true, items, page: pageNumber, has_next: hasNext, account };
        }
        if (!["subscribe", "unsubscribe"].includes(request.action) || !/^[1-9][0-9]*$/.test(request.item_id))
            return failure("invalid_request", "Invalid Workshop action.");
        if (new URL(location.href).searchParams.get("id") !== request.item_id)
            return failure("wrong_item", "The loaded Workshop item does not match the selected wallpaper.");
        const subscribe = document.querySelector("#SubscribeItemBtn");
        const appLinks = Array.from(document.querySelectorAll('a[href*="/app/431960"], a[href*="appid=431960"]'));
        if (!subscribe || !appLinks.length)
            return failure("unsupported_item", "This item does not expose Wallpaper Engine subscription controls.");
        const isSubscribed = subscribe.classList.contains("toggled");
        if (request.action === "subscribe" && isSubscribed)
            return { ok: true, item_id: request.item_id, subscribed: true, existing: true, message: "Already subscribed on Steam." };
        if (request.action === "unsubscribe" && !isSubscribed)
            return { ok: true, item_id: request.item_id, subscribed: false, existing: true, message: "Already unsubscribed on Steam." };
        const session = globalThis.g_sessionID;
        if (typeof session !== "string" || !session)
            return failure("authentication_required", "Your Steam session expired. Reconnect your account.");
        const endpoint = request.action === "unsubscribe" ? "/sharedfiles/unsubscribe" : "/sharedfiles/subscribe";
        const response = await fetch(endpoint, {
            method: "POST", credentials: "same-origin", redirect: "error",
            headers: { "X-Requested-With": "XMLHttpRequest", "Accept": "application/json" },
            body: new URLSearchParams({ id: request.item_id, appid: "431960", sessionid: session })
        });
        if (response.status === 401 || response.status === 403)
            return failure("authentication_required", "Steam rejected this session. Reconnect your account.");
        if (!response.ok)
            return failure(request.action + "_failed", "Steam did not accept the subscription change. Check the website before retrying.");
        const result = await response.json();
        if (result.success !== 1)
            return failure(result.success === 21 ? "authentication_required" : request.action + "_failed", "Steam did not confirm the subscription change. Your account may not have permission or may have reached its subscription limit.");
        const verified = await getPage("/sharedfiles/filedetails/?id=" + request.item_id);
        const verifiedButton = verified.querySelector("#SubscribeItemBtn");
        const verifiedSubscribed = Boolean(verifiedButton && verifiedButton.classList.contains("toggled"));
        if (!verifiedButton || verifiedSubscribed !== (request.action === "subscribe"))
            return failure("verification_failed", "Steam accepted the request but the subscription state could not be verified. Check the website before retrying.");
        return { ok: true, item_id: request.item_id, subscribed: verifiedSubscribed, message: request.action === "unsubscribe" ? "Unsubscribed from Steam." : "Subscribed on Steam." };
    } catch (error) {
        return failure("request_failed", "The website request failed or its response changed. Check your connection and the website before retrying.");
    }
}
