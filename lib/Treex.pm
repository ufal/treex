package Treex;

use strict;
use warnings;
1;

__END__

=encoding utf-8

=head1 NAME

Treex - Natural Language Processing framework

=head1 INTRODUCTION

Treex (formerly named TectoMT) is a highly modular, multi-purpose,
multi-lingual, easily extendable Natural Language Processing framework.

Treex has the following features:

- There is a number of NLP tools already integrated in Treex,
  such as morphological tagger, lemmatizers, named entity recognizers,
  dependency parsers, constituency parsers, various kinds of dictionaries.

- Treex allows storing all data in an XML-based format, which
  simplifies data interchange with other frameworks.

- Treex is tightly coupled with the tree editor TrEd, which
  allows easy visualization of syntactic structures.

- Treex is language universal and supports processing multilingual
  parallel data.

- Treex facilitates distributed processing on a computer cluster.

- Treex architecture is inspired by the Prague Dependency Treebank,
  especially by its layered view on language (especially distinguishing
  surface syntax and deep syntax). Linguistic data structures used in
  Treex are highly similar to the PDT's data structures.

- Treex has been used for deep analysing large data, such as for Czech-English
  parallel treebank CzEng (millions of parallel sentence pairs).

- Treex has been intensively used for several years for developing a
  Czech-English machine translation system, which is currently the main,
  but not the only one application of Treex.

In a way, Treex is similar to GATE. However, in our opinion, Treex has
a better support for deeply structured language data and for processing
multilingual data.

=head1 COMPONENTS

Treex is divided into several distributions:

=head2 Treex::PML distribution

PML stands for Prague Markup Language (PML), which is an XML-based data
format developed for interchange of linguistic data. L<Treex::PML>
comprises of a set of modules defining abstract Perl types (such
as tree nodes) and related functionality (such as tree traversal),
as well as procedures for storing the data structures into (and loading
from) PML files. L<Treex::PML> is a universal format, with only a few
assumptions about linguistic data.

L<Treex::PML> was developed by Petr Pajas, originally under the name
Fslib as a part of the tree editor Tred, long before other components of
TectoMT/Treex were created.

=head2 Treex::Core distribution

L<Treex::Core> is an additional level of functionality added to
L<Treex::PML>. Most L<Treex::Core> classes are
descendants of L<Treex::PML> classes.

Unlike L<Treex::PML>, L<Treex::Core> is not meant to be 
a universal library for linguistic data. L<Treex::Core> predefines 
several quite specific types of linguistic data structures; this limitation 
allows L<Treex::Core> to provide functionality designed 
specifically for these structures (such as resolving coordination, links 
between deep and surface syntax, clause segmentation, alignment of parallel 
data, etc.). Moreover, L<Treex::Core> offers tools for distributed 
processing of Treex files, and for their visualization in TrEd.
Like L<Treex::PML>, L<Treex::Core> is language universal.

=head2 Language specific distributions

Language specific components of Treex are planned to be released on CPAN
within 2011.


=head1 HISTORY

Treex results from an active long-term NLP research carried out at the Institute
of Formal and Applied Linguistics (Faculty of Mathematics and Physics, Charles University
in Prague, Czech Republic). The following list surveys only selected technological shifts:


1996 - Michal Křen develops the Graph tree editor. Linguistic data structures are stored in
a proprietary data format called fs-format.

1997 - an SGML-based format called CSTS (Czech sentence tree structure) is developed.
In 2001, CSTS becomes the primary data format of the Prague Dependency Treebank 1.0.

2000 - Petr Pajas develops an alternative tree editor called TrEd (in Perl), which soon becomes
the main tool used for various types of annotations realized in the department, and is used abroad
as well. TrEd contained a library of modules for memory representation of
linguistic structures and their storage, called Fslib.

2000-2005 - Numerous NLP modules were developed at the department, aimed either at exploiting the existing PDT data, or
at facilitating new linguistic annotations. A new generic (language-universal, theory-universal)
XML-based format called Prague Markup Language is developed. PML was the primary format
of Jan Hajič et al.'s  PDT 2.0 in 2006.

2005 - Zdeněk Žabokrtský starts the development of TectoMT, with the aim of creating a modular
NLP system, primarily focused on Machine Translation with deep-syntactic (tectogrammatical) transfer.

2006 - First TectoMT-based English-Czech Machine Translation experiments are performed.

2006-2010 -  TectoMT's architecture, as well as the translation quality, are gradually improved
(several thousand svn revisions).  Many NLP tools such as taggers and parsers for various
languages are  integrated.

2010 - Fslib separated from TrEd, and published as a CPAN module under the name C<Treex::PML>.

2010-2011 - "TectoMT" is rebranded to "Treex" - "eXploit syntactic/semantic TREEs!". All core components
are refactored using Moose.

2011 - The  C<Treex::Core> components are packed and go to CPAN. Some other (language specific)
distributions are hoped to appear soon too.

=head1 REFERENCES

L<Treex website|http://ufal.mff.cuni.cz/treex>

Selected TectoMT/Treex-related publications:

- Žabokrtský Zdeněk, Ptáček Jan, Pajas Petr:
TectoMT: Highly Modular MT System with Tectogrammatics Used as Transfer Layer.
In: ACL 2008 WMT: Proceedings of the Third Workshop on Statistical Machine Translation,
Copyright © Association for Computational Linguistics, Columbus, OH, USA,
ISBN 978-1-932432-09-1, pp. 167-170, 2008

- Žabokrtský Zdeněk, Bojar Ondřej: TectoMT, Developer's Guide.
Technical report no. 2008/TR-2008-39, Copyright © Institute of Formal and Applied Linguistics,
Faculty of Mathematics and Physics, Charles University in Prague, 50 pp., Dec 2008

- Popel Martin, Žabokrtský Zdeněk: TectoMT: Modular NLP Framework.
In: Lecture Notes in Computer Science, Vol. 6233, Proceedings of the 7th International Conference
on Advances in Natural Language Processing (IceTAL 2010), Copyright © Springer,
Berlin / Heidelberg, ISBN 978-3-642-14769-2, ISSN 0302-9743, pp. 293-304, 2010

- Mareček David, Popel Martin, Žabokrtský Zdeněk: Maximum Entropy Translation Model in Dependency-Based
MT Framework. In: Proceedings of the Joint Fifth Workshop on Statistical Machine Translation and MetricsMATR,
Copyright © Association for Computational Linguistics, Uppsala, Sweden, ISBN 978-1-932432-71-8, pp. 201-201, 2010


=head1 AUTHOR

Treex is an open project, there is a number of people who have contributed.

=head2 Treex Cabal (not very original, is it?)

Those who are responsible for maintaining Treex::Core modules.

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head2 Author of TrEd and Treex::PML

Petr Pajas

=head2 Some other contributors to Treex, both present and past, alphabetically

Ondřej Bojar

Václav Klimeš

Tomáš Kraut

Václav Novák

Jan Ptáček

Rudolf Rosa

Daniel Zeman

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
