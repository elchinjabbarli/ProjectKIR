#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Level doğrulayıcı — spec 158.
Kullanım: python3 Tools/LevelValidator/validate_levels.py
Kontroller: şema, bilinen tipler, benzersiz ID'ler, linked hedeflerinin varlığı,
checkpoint ve exit varlığı.
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "ProjectKIR", "Resources", "Levels")
KNOWN = {"door", "valve", "mirror", "platform", "counterweight", "bridge",
         "receiver", "drone", "pressurewave", "debris", "silt", "electric", "exit"}
SOLIDS = {"ground", "wall", "platform", "lowceiling", "cover", "ceiling", "decor"}


def linked_ids(entity):
    """Entity JSON'unda 'linked' ya da properties.linked.list biçiminde hedefler."""
    if "linked" in entity:
        return entity["linked"]
    props = entity.get("properties") or {}
    val = props.get("linked")
    if isinstance(val, list):
        return val
    return []


def main():
    if not os.path.isdir(ROOT):
        print("Level klasörü bulunamadı:", ROOT)
        return 1
    levels = sorted(f for f in os.listdir(ROOT) if f.endswith(".json"))
    if not levels:
        print("Level bulunamadı:", ROOT)
        return 1
    problems_total = 0
    for fn in levels:
        d = json.load(open(os.path.join(ROOT, fn), encoding="utf-8"))
        problems = []
        if d["camera"]["right"] <= d["camera"]["left"]:
            problems.append("kamera sol/sağ")
        if not d["checkpoints"]:
            problems.append("checkpoint yok")
        if not any(e["type"] == "exit" for e in d["entities"]):
            problems.append("exit yok")
        ids = [e["id"] for e in d["entities"]]
        if len(ids) != len(set(ids)):
            problems.append("tekrar eden entity id")
        for e in d["entities"]:
            if e["type"] not in KNOWN:
                problems.append("bilinmeyen entity: " + e["type"])
            for target in linked_ids(e):
                if target and target not in ids:
                    problems.append(f"{e['id']} -> eksik hedef {target}")
        for s in d["solids"]:
            if s["type"] not in SOLIDS:
                problems.append("bilinmeyen solid: " + s["type"])
        # Kademeli frekans kilidi — kilitli frekans gerektiren bulmaca softlock olur (spec 894).
        freqs = set(d.get("frequencies") or ["deep", "body", "edge"])
        used = set()
        for e in d["entities"]:
            props = e.get("properties") or {}
            if "frequency" in props:
                used.add(props["frequency"])
            if "frequency" in e:
                used.add(e["frequency"])
            for s in (props.get("sequence") or e.get("sequence") or []):
                if isinstance(s, str):
                    used.add(s)
        locked = used - freqs
        if locked:
            problems.append("kilitli ama kullanılan frekanslar: " + ", ".join(sorted(locked)))
        status = "OK   " if not problems else "SORUN"
        suffix = ": " + "; ".join(problems) if problems else ""
        print(f"{status} {fn}{suffix}")
        problems_total += len(problems)
    print(f"\n{len(levels)} level tarandı, {problems_total} sorun.")
    return 1 if problems_total else 0


if __name__ == "__main__":
    sys.exit(main())
