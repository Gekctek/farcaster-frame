import FHM "mo:StableHashMap/FunctionalStableHashMap";
import SHA256 "mo:motoko-sha/SHA256";
import CertTree "mo:ic-certification/CertTree";
import CanisterSigs "mo:ic-certification/CanisterSigs";
import CertifiedData "mo:base/CertifiedData";
import HTTP "mo:certified-cache/Http";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import CertifiedCache "mo:certified-cache";
import Int "mo:base/Int";

actor Self {
    type HttpRequest = HTTP.HttpRequest;
    type HttpResponse = HTTP.HttpResponse;

    var two_days_in_nanos = 2 * 24 * 60 * 60 * 1000 * 1000 * 1000;

    var entries : [(Text, (Blob, Nat))] = [];
    var cache = CertifiedCache.fromEntries<Text, Blob>(
        entries,
        Text.equal,
        Text.hash,
        Text.encodeUtf8,
        func(b : Blob) : Blob { b },
        two_days_in_nanos + Int.abs(Time.now()),
    );

    public query func keys() : async [Text] {
        return Iter.toArray(cache.keys());
    };

    public query func http_request(req : HttpRequest) : async HttpResponse {
        let cached = cache.get(req.url);

        switch cached {
            case (?body) {
                // Print the body of the response
                let message = Text.decodeUtf8(body);
                switch message {
                    case (null) {};
                    case (?m) {
                        Debug.print(m);
                    };
                };
                let response : HttpResponse = {
                    status_code : Nat16 = 200;
                    headers = [("content-type", "text/html"), cache.certificationHeader(req.url)];
                    body = body;
                    streaming_strategy = null;
                    upgrade = null;
                };

                return response;
            };
            case null {
                Debug.print("Request was not found in cache. Upgrading to update request.\n");
                return {
                    status_code = 404;
                    headers = [];
                    body = Blob.fromArray([]);
                    streaming_strategy = null;
                    upgrade = ?true;
                };
            };
        };
    };

    public func http_request_update(req : HttpRequest) : async HttpResponse {
        let url = req.url;

        Debug.print("Storing request in cache.");
        let time = Time.now();
        let message = "<pre>Request has been stored in cache: \n" # "URL is: " # url # "\n" # "Method is " # req.method # "\n" # "Body is: " # debug_show req.body # "\n" # "Timestamp is: \n" # debug_show Time.now() # "\n" # "</pre>";

        if (req.url == "/" or req.url == "/index.html") {
            let page = main_page();
            let response : HttpResponse = {
                status_code : Nat16 = 200;
                headers = [("content-type", "text/html")];
                body = page;
                streaming_strategy = null;
                upgrade = null;
            };

            let put = cache.put(req.url, page, null);
            return response;
        } else {
            let page = page_template(message);

            let response : HttpResponse = {
                status_code : Nat16 = 200;
                headers = [("content-type", "text/html")];
                body = page;
                streaming_strategy = null;
                upgrade = null;
            };

            let put = cache.put(req.url, page, null);

            // update index
            let indexBody = main_page();
            cache.put("/", indexBody, null);

            return response;
        };
    };

    func page_template(body : Text) : Blob {
        return Text.encodeUtf8(
            "<html>"
            # "<head>"
            # "<meta name='viewport' content='width=device-width, initial-scale=1'>"
            # "<meta property=\"fc:frame\" content=\"vNext\" />"
            # "<meta property=\"fc:frame:image\" content=\"https://daoball.xyz/images/fractal_ball_hu8f8ba46e286fe096037603c2627e2c54_2266596_240x0_resize_q90_h2_lanczos_3.webp\" />"
            # "<meta property=\"fc:frame:button:1\" content=\"Green\" />"
            # "<meta property=\"fc:frame:button:2\" content=\"Purple\" />"
            # "<meta property=\"fc:frame:button:3\" content=\"Red\" />"
            # "<meta property=\"fc:frame:button:4\" content=\"Blue\" />"
            # "<title>DAOball farcaster frame</title>"
            # "</head>"
            # "<body>"
            # "<div class='container' role='document'>"
            # body
            # "</div>"
            # "</body>"
            # "</html>"
        );
    };

    func my_id() : Principal = Principal.fromActor(Self);

    func main_page() : Blob {
        page_template(
            "<p>This is a Farcaster frame for DAOball (<a href='https://daoball.xyz'>DAOball.xyz</a>) hosted on the <a href='https://internetcomputer.org'>Internet Computer</a>.</p>"
        );
    };

    func value_page(key : Text) : Blob {
        switch (cache.get(key)) {
            case (null) { page_template("<p>Key " # key # " not found.</p>") };
            case (?v) {
                v;
            };
        };
    };

    /*
  * Convenience function to implement SHA256 on Blobs rather than [Int8]
  */

    system func preupgrade() {};

    // If your CertTree.Store is stable, it is recommended to prune all signatures in pre or post-upgrade:
    system func postupgrade() {
        let _ = cache.pruneAll();
    };

};
