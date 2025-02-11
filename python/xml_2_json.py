#!/usr/bin/env python3

import xml.etree.ElementTree as ET
import json
import argparse


def xml_to_json(xml_string):
    """
    将 XML 字符串转换为 JSON 字符串。

    Args:
        xml_string (str): XML 格式的字符串。

    Returns:
        str: JSON 格式的字符串。
    """
    try:
        root = ET.fromstring(xml_string)
        return element_to_json(root)
    except ET.ParseError as e:
        raise ValueError(f"XML 解析错误: {e}")


def element_to_json(element):
    """
    递归地将 XML 元素及其子元素转换为 JSON 对象。

    Args:
        element (ElementTree.Element): XML 元素。

    Returns:
        dict, str, or None: JSON 对象，字符串，或 None (如果元素为空且没有文本)。
    """
    obj = {}
    # 处理属性
    if element.attrib:
        obj["_attributes"] = element.attrib

    # 处理文本内容
    if element.text and element.text.strip():
        text = element.text.strip()
        if not obj:  # 如果obj还是空的，说明没有属性，直接返回文本
            return text
        else:  # 如果obj已经有属性了，将文本也放进去，key可以设置为 '_text'
            obj["_text"] = text

    # 递归处理子元素
    for child in element:
        child_json = element_to_json(child)
        if child.tag in obj:
            if isinstance(obj[child.tag], list):
                obj[child.tag].append(child_json)
            else:
                obj[child.tag] = [
                    obj[child.tag],
                    child_json,
                ]  # 将之前的value和新的value都放入list
        else:
            obj[child.tag] = child_json

    if not obj and not element.text:  # 如果obj还是空的，并且元素也没有文本，返回 None
        return None

    return obj if obj else None  # 如果obj是空的，返回 None， 否则返回 obj


def convert_file_xml_to_json(xml_filepath, json_filepath=None):
    """
    将 XML 文件转换为 JSON 文件。

    Args:
        xml_filepath (str): XML 文件路径。
        json_filepath (str, optional): JSON 文件路径。如果为None，则打印到控制台。
    """
    try:
        with open(xml_filepath, "r", encoding="utf-8") as xml_file:
            xml_string = xml_file.read()
            json_output = xml_to_json(xml_string)
            if json_filepath is None:
                print(json.dumps(json_output, indent=4, ensure_ascii=False))
            else:
                with open(json_filepath, "w", encoding="utf-8") as json_file:
                    json.dump(json_output, json_file, indent=4, ensure_ascii=False)
                print(f"成功将 XML 文件 '{xml_filepath}' 转换为 JSON 文件 '{json_filepath}'")
    except FileNotFoundError:
        print(f"错误: 文件 '{xml_filepath}' 未找到")
    except ValueError as e:
        print(f"转换错误: {e}")
    except Exception as e:
        print(f"发生未知错误: {e}")


def main():
    parser = argparse.ArgumentParser(description='将XML文件转换为JSON格式')
    parser.add_argument('--input', required=True, help='输入的XML文件路径')
    parser.add_argument('--output', help='输出的JSON文件路径（可选，若不指定则输出到控制台）')
    
    args = parser.parse_args()
    convert_file_xml_to_json(args.input, args.output)


if __name__ == "__main__":
    main()
