package Treex;
use strict;
use warnings;
1;

__END__

=encoding utf-8

=head1 NAME

Treex - NLP framework

=head1 INTRODUCTION

Treex (formerly named TectoMT) is a highly modular, multi-purpose,
easily extendable Natural Language Processing framework.

Treex architecture is inspired by the Prague Dependency Treebank,
especially in layered view on language, in using dependency
representation of syntactic structures, and in distinguishing
morphology, surface syntax and deep syntax. Treex also reuses
the NLP technology developed within the PDT project.

The pilot application of Treex is Machine Translation. However,
Treex/TectoMT has been used for several other tasks as well.
??? TODO L<Treex::Manual::Applications>

Nowadays, there is a number of NLP tools integrated in TectoMT/Treex.
??? TODO L<Treex::Manual::IntegratedTools>

=head1 COMPONENTS

=head2 Treex::PML distribution

PML stands for Prague Markup Language (PML), which is an XML-based data
format developed for interchange of linguistic data. L<Treex::PML>
comprises of a set of modules defining abstract Perl types (such
as tree nodes) and related functionality (such as tree traversal),
as well as procedures for storing the data structures into (and loading
from) PML files. Treex::PML is a universal format, with only a few
assumptions about linguistic data.

Treex::PML was developed by Petr Pajas, originally under the name Fslib
as a part of Tree editor Tred and long before other components of TectoMT/Treex
were created.

=head2 Treex::Core distribution

L<Treex::Core> is an additional level of functionality added to Treex::PML.
Most Treex::Core classes are descendants of Treex::PML classes.

Unlike Treex::PML, Treex::Core is not meant to be a universal
library for linguistic data. Treex::Core predefines several quite specific
types of linguistic data structures; this limitation allows Treex::Core
to provide functionality designed specifically for these structures
(such as resolving coordination, links between deep and surface syntax,
clause segmentation, alignment of parallel data, etc.).
Moreover, Treex::Core offers tools for distributed processing
of Treex files, and for their visualization in TrEd.

Like Treex::PML, Treex::Core is language universal.

=head2 Language specific distributions

... are expected to be released soon.

=head1 HISTORY

1996 - tree editor Graph by Michal Kren (predecessor of TrEd)

1999 - Petr Pajas started development of tree editor TrEd, inheriting the Graph's data format (fs-format)

2000-2005 - developing various Perl modules for PDT data, developing Prague Markup Language

2006 - Jan Hajic et al.'s  PDT 2.0 was released (data completely in PML)

2005 - Zdenek Zabokrtsky started the development of TectoMT

2006 - first TectoMT-based English-Czech Machine Translation prototype,

2006-2010 - numerous (both tiny and big-bang) improvements of TectoMT architecture;
     integrating a number of NLP tools (taggers, parsers, ...) into TectoMT

2010 - Fslib separated from TrEd, and restructured to a CPAN, Treex::PML

2010-2011 - rebranding TectoMT-->Treex (exploit syntactic trees), shift to Moose at the same time

2011 - Treex::Core goes to CPAN

=head1 REFERENCES

Selected TectoMT/Treex-related publications:

Žabokrtský Zdeněk, Ptáček Jan, Pajas Petr:
TectoMT: Highly Modular MT System with Tectogrammatics Used as Transfer Layer.
In: ACL 2008 WMT: Proceedings of the Third Workshop on Statistical Machine Translation,
Copyright © Association for Computational Linguistics, Columbus, OH, USA,
ISBN 978-1-932432-09-1, pp. 167-170, 2008

Žabokrtský Zdeněk, Bojar Ondřej: TectoMT, Developer's Guide.
Technical report no. 2008/TR-2008-39, Copyright © Institute of Formal and Applied Linguistics,
Faculty of Mathematics and Physics, Charles University in Prague, 50 pp., Dec 2008

Popel Martin, Žabokrtský Zdeněk: TectoMT: Modular NLP Framework.
In: Lecture Notes in Computer Science, Vol. 6233, Proceedings of the 7th International Conference
on Advances in Natural Language Processing (IceTAL 2010), Copyright © Springer,
Berlin / Heidelberg, ISBN 978-3-642-14769-2, ISSN 0302-9743, pp. 293-304, 2010


=head1 AUTHOR

Treex is an open project, there is a number of people who have contributed.

=head2 Treex Cabal

Those who are responsible for developing and releasing Treex::Core modules.

Zdenek Zabokrtsky

Martin Popel

David Marecek

=head2 Author of TrEd and Treex::PML

Petr Pajas

=head2 Other contributors (both present and past)

Jan Ptacek

Ondrej Bojar

Vaclav Novak

Tomas Kraut


=head1 COPYRIGHT AND LICENSE

Copyright 2006-2011 Institute of Formal and Applied Linguistics, Charles University in Prague

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
