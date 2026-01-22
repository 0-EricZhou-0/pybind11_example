# Automated Build System for Pybind11 Projects <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->
- [Features](#features)
- [Install Dependencies](#install-dependencies)
- [Setup](#setup)
- [Note](#note)


## Features

TBA

## Install Dependencies

```shell ln:false
# include third party libraries, including pybind11 and pybind11_mkdoc (and potentially others)
git submodule update --init --recursive
# for configuring dependencies
python3 -m pip install packaging pip-tools
```

## Setup

```shell ln:false
mkdir build && cd build
cmake ..
make generate_py3_requirements
python3 -m pip install -r ../requirements.txt
make <MODULE_NAME>_pymod
```

To configure the name of the module and where the output product (CPython library) should be positioned, modify corresponding variables in `csrc/module_defs.cmake`.

## Note

This comes with protobuf v30.2 (v6.30.2) located in `third_party/protobuf`.
