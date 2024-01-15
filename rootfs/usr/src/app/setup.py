import setuptools

setuptools.setup(
    name="hook-operator",
    version="0.0.1",
    author="Andrew Cole",
    author_email="andrew.cole@illallangi.com",
    description="TODO: SET DESCRIPTION",
    long_description="TODO: SET LONG DESCRIPTION",
    long_description_content_type="text/markdown",
    url="https://github.com/illallangi/controllers",
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.6",
    entry_points={
        "console_scripts": ["hook=hook_operator:__main__.main"],
    },
    install_requires=[
        "click",
        "python-frontmatter",
        "Jinja2",
        "jinja2-ansible-filters",
        "jinja2-getenv-extension",
    ],
)
