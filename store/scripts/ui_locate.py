import re
import sys
import xml.etree.ElementTree as ElementTree


def bounds(node):
    left, top, right, bottom = map(int, re.findall(r"\d+", node.get("bounds", "")))
    return left, top, right, bottom


def matches(node, label):
    text = node.get("text", "")
    description = node.get("content-desc", "")
    return label in (text, description) or text.startswith(label + "\n")


def main():
    label, mode, occurrence = sys.argv[1], sys.argv[2], sys.argv[3]
    root = ElementTree.fromstring(sys.stdin.read())
    nodes = [node for node in root.iter("node") if matches(node, label)]
    if not nodes:
        sys.exit(1)
    left, top, right, bottom = bounds(nodes[-1] if occurrence == "last" else nodes[0])
    y = (top + bottom) // 2
    if mode == "left":
        print(left + max((bottom - top) // 2, 12), y)
    elif mode == "start":
        print(left + 24, y)
    else:
        print((left + right) // 2, y)


main()
