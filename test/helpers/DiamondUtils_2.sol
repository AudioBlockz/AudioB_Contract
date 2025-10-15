// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

abstract contract DiamondUtils_2 is Test {
    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        // Run forge inspect
        string[] memory cmd = new string[](4);
        cmd[0] = "forge";
        cmd[1] = "inspect";
        cmd[2] = _facetName;
        cmd[3] = "methods";

        bytes memory res = vm.ffi(cmd);
        string memory output = string(res);

        console.log("Inspect output for", _facetName, "=>", output);

        bytes memory out = bytes(output);
        
        // First pass: count valid selectors
        // Look for pattern: "| " followed by exactly 8 hex chars followed by " " or "|"
        uint256 count = 0;
        for (uint256 i = 0; i < out.length; i++) {
            if (i + 10 < out.length && out[i] == "|" && out[i + 1] == " ") {
                // Check if next 8 chars are all hex
                bool allHex = true;
                for (uint256 j = 0; j < 8; j++) {
                    if (!_isHexChar(out[i + 2 + j])) {
                        allHex = false;
                        break;
                    }
                }
                
                // Verify it ends with whitespace or pipe (not more hex chars)
                if (allHex && i + 10 < out.length) {
                    bytes1 nextChar = out[i + 10];
                    // Must be followed by space, pipe, or newline (not another hex char)
                    if (nextChar == " " || nextChar == "|" || nextChar == "\n" || nextChar == 0x20) {
                        count++;
                    }
                }
            }
        }

        selectors = new bytes4[](count);
        uint256 index = 0;

        // Second pass: extract selectors
        for (uint256 i = 0; i < out.length && index < count; i++) {
            if (i + 10 < out.length && out[i] == "|" && out[i + 1] == " ") {
                // Check if next 8 chars are all hex
                bool allHex = true;
                bytes memory hexBytes = new bytes(8);
                
                for (uint256 j = 0; j < 8; j++) {
                    bytes1 c = out[i + 2 + j];
                    if (!_isHexChar(c)) {
                        allHex = false;
                        break;
                    }
                    hexBytes[j] = c;
                }
                
                // Verify it ends with whitespace or pipe
                if (allHex && i + 10 < out.length) {
                    bytes1 nextChar = out[i + 10];
                    if (nextChar == " " || nextChar == "|" || nextChar == "\n" || nextChar == 0x20) {
                        uint32 val = _fromHex(hexBytes);
                        bytes4 sel = bytes4(val);
                        
                        // Additional safety: skip if selector is 0x00000000
                        if (sel != bytes4(0)) {
                            selectors[index++] = sel;
                        }
                    }
                }
            }
        }

        // Trim array if we found fewer valid selectors than expected
        if (index < count) {
            bytes4[] memory trimmed = new bytes4[](index);
            for (uint256 i = 0; i < index; i++) {
                trimmed[i] = selectors[i];
            }
            selectors = trimmed;
        }

        require(selectors.length > 0, "No selectors found");
        console.log(_facetName, "selectors found:", selectors.length);
        
        return selectors;
    }

    function _isHexChar(bytes1 c) private pure returns (bool) {
        return
            (c >= "0" && c <= "9") ||
            (c >= "a" && c <= "f") ||
            (c >= "A" && c <= "F");
    }

    function _fromHex(bytes memory str) private pure returns (uint32 result) {
        for (uint256 i = 0; i < str.length; i++) {
            uint8 c = uint8(str[i]);
            result <<= 4;
            if (c >= 48 && c <= 57) result |= c - 48; // 0-9
            else if (c >= 97 && c <= 102) result |= c - 87; // a-f
            else if (c >= 65 && c <= 70) result |= c - 55; // A-F
        }
    }
}
