#!/usr/bin/env python3
import click
import frontmatter
import jinja2
import json
import operator
import os
import re
import yaml
from itertools import groupby

def unique_justseen(iterable, key=None):
    "List unique elements, preserving order. Remember only the element just seen."
    # unique_justseen('AAAABBBCCDAABBB') --> A B C D A B
    # unique_justseen('ABBcCAD', str.lower) --> A B c A D
    return map(next, map(operator.itemgetter(1), groupby(iterable, key)))

@click.command()
@click.argument(
    "path",
    type=click.STRING,
    required=True,
)
@click.argument(
    "context", type=click.File("r"), required=False, envvar="BINDING_CONTEXT_PATH"
)
@click.argument(
    "hooksdir", type=click.STRING, required=False, envvar="SHELL_OPERATOR_HOOKS_DIR"
)
@click.argument(
    "patchpath", type=click.STRING, required=False, envvar="KUBERNETES_PATCH_PATH"
)
@click.argument(
    "debugpath", type=click.STRING, required=False, envvar="HOOK_OPERATOR_DEBUG_PATH", default="/debug"
)
@click.option(
    "--config",
    is_flag=True,
)
def main(
    path,
    context,
    hooksdir,
    patchpath,
    debugpath,
    config,
):
    # Load frontmatter from path, stripping shebang if present
    with open(path) as f:
        content = f.read()
    options, template = frontmatter.parse(re.sub(r"^#.*\n", "", content))

    # If config flag is set, output config
    if config:
        click.echo(
            json.dumps(
                {
                    "configVersion": "v1",
                    "kubernetes": [
                        {
                            "name": f'{k["apiVersion"]}/{k["kind"]}{path.replace(hooksdir, "")}',
                            "apiVersion": k["apiVersion"],
                            "kind": k["kind"],
                            "executeHookOnEvent": [
                                "Added",
                                "Modified",
                            ],
                            "executeHookOnSynchronization": True,
                            "keepFullObjectsInMemory": True,
                            "queue": f'{k["apiVersion"]}/{k["kind"]}{path.replace(hooksdir, "")}',
                        }
                        for k in options["kinds"]
                    ],
                },
            ),
        )
        return

    for binding in json.load(context):
        for obj in [b["object"] for b in binding.get("objects", [binding])]:
            patch = dotemplate(
                binding,
                options,
                template,
                obj,
                debugpath,
            )
            if patch is not None:
                with open(patchpath, "a") as f:
                    f.write(
                        json.dumps(
                            patch,
                            indent=2,
                        )
                    )

def dotemplate(
    binding,
    options,
    template,
    _object,
    debugpath,
):
    _component = {
        **_object,
        'metadata': {
            "labels": {
                k: (v if v is not None else '')
                for k, v in
                {
                    **_object.get("metadata", {}).get("labels", {}),
                    "app.kubernetes.io/class": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/class", "").lower(),
                    "app.kubernetes.io/component": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component", options.get("component", "")).lower(),
                    "app.kubernetes.io/instance": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/instance", _object.get("metadata", {}).get("name")).lower(),
                    "app.kubernetes.io/managed-by": options.get("operator", "operator.illallangi.enterprises").lower(),
                    "app.kubernetes.io/name": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", _object.get("kind", "")).lower(),
                }.items()
            },
            "name": "-".join(
                unique_justseen(
                    [
                        x
                        for x in [
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", _object.get("kind", "")).lower(),
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/class", "").lower(),
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/instance", _object.get("metadata", {}).get("name"),).lower(),
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component", options.get("component", "")).lower(),
                        ]
                        if x is not None and x != ""
                    ]
                ),
            ),
            "namespace": _object.get("metadata", {}).get("namespace"),
            "ownerReferences": [
                {
                    "apiVersion": _object.get("apiVersion"),
                    "kind": _object.get("kind"),
                    "name": _object.get("metadata", {}).get("name"),
                    "uid": _object.get("metadata", {}).get("uid"),
                }
            ],
        },
        'selector': 
        {
            k: (v if v is not None else '')
            for k, v in
            {
                "app.kubernetes.io/class": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/class", "").lower(),
                "app.kubernetes.io/component": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component", options.get("component", "")).lower(),
                "app.kubernetes.io/instance": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/instance", _object.get("metadata", {}).get("name")).lower(),
                "app.kubernetes.io/name": _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", _object.get("kind", "")).lower(),
            }.items()
        },
    }

    _instance = {
        **_component,
        'metadata': {
            **_component.get("metadata", {}),
            "labels": {
                k: (v if k not in [
                    "app.kubernetes.io/component",
                ] else '')
                for k, v in _component['metadata']['labels'].items()
            },
            "name": "-".join(
                unique_justseen(
                    [
                        x
                        for x in [
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", _object.get("kind", "")).lower(),
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/class", "").lower(),
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/instance", _object.get("metadata", {}).get("name"),).lower(),
                        ]
                        if x is not None and x != ""
                    ]
                ),
            ),
        },
        'selector': {
            k: (v if k not in [
                "app.kubernetes.io/component",
            ] else '')
            for k, v in _component['selector'].items()
        },
    }

    _class = {
        **_instance,
        'metadata': {
            **_instance.get("metadata", {}),
            "labels": {
                k: (v if k not in [
                    "app.kubernetes.io/instance",
                ] else '')
                for k, v in _instance['metadata']['labels'].items()
            },
            "name": "-".join(
                unique_justseen(
                    [
                        x
                        for x in [
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", _object.get("kind", "")).lower(),
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/class", "").lower(),
                        ]
                        if x is not None and x != ""
                    ]
                ),
            ),
        },
        'selector': {
            k: (v if k not in [
                "app.kubernetes.io/instance",
            ] else '')
            for k, v in _instance['selector'].items()
        },
    }

    _application = {
        **_class,
        'metadata': {
            **_class.get("metadata", {}),
            "labels": {
                k: (v if k not in [
                    "app.kubernetes.io/class",
                ] else '')
                for k, v in _class['metadata']['labels'].items()
            },
            "name": "-".join(
                unique_justseen(
                    [
                        x
                        for x in [
                            _object.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", _object.get("kind", "")).lower(),
                        ]
                        if x is not None and x != ""
                    ]
                ),
            ),
        },
        'selector': {
            k: (v if k not in [
                "app.kubernetes.io/class",
            ] else '')
            for k, v in _class['selector'].items()
        },
    }

    if debugpath is not None:
        os.makedirs(f'{debugpath}/{binding["binding"]}', exist_ok=True)

        with open(f'{debugpath}/{binding["binding"]}/template.yaml.j2', "w") as f:
            f.write(template)

        with open(f'{debugpath}/{_object["metadata"]["uid"]}.json', "w") as f:
            json.dump(
                {
                    'object': _object,
                    'component': _component,
                    'instance': _instance,
                    'class': _class,
                    'application': _application,
                },
                f,
                indent=2
            )

    jinja_result = jinja2.Template(
        template,
        extensions=[
            "jinja2_ansible_filters.AnsibleCoreFiltersExtension",
            "jinja2_getenv_extension.GetenvExtension",
        ],
    ).render(
        _options=options,
        _object=_object,
        _component=_component,
        _instance=_instance,
        _class=_class,
        _application=_application,
    )

    if debugpath is not None:
        with open(f'{debugpath}/{binding["binding"]}/{_object["metadata"]["uid"]}.yaml', "w") as f:
            f.write(jinja_result)

    output = yaml.safe_load(jinja_result)

    if (output is None) or (output == {}):
        return
    
    if debugpath is not None:
        with open(f'{debugpath}/{binding["binding"]}/{_object["metadata"]["uid"]}.yaml', "w") as f:
            f.write(yaml.dump(output))

    return {
        "operation": options.get("operation", "CreateOrUpdate"),
        "object": output,
    }


if __name__ == "__main__":
    main()
