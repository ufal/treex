package PMLTQ::Relation::Treex;

#
# This file implements the following user-defined relations for PML-TQ
#
# - eparentC, echildC - Slightly modified (skipping only coordinarion nodes) eparent/echild for a-layer
# - eparent (both t-layer and a-layer)
# - echild (both t-layer and a-layer)
#
#################################################

{
  package PMLTQ::Relation::Treex::AEParentCIterator;
  use strict;
  use base qw(PMLTQ::Relation::SimpleListIterator);
  use PMLTQ::Relation {
      name => 'eparentC',
      reversed_relation => 'implementation:echildC',
      start_node_type => 'a-node',
      target_node_type => 'a-node',
      iterator_class => __PACKAGE__,
      test_code => q(grep($_ == $end, TreexUtils::AGetEParentsC($start)) ? 1 : 0),
  };
  sub get_node_list  {
    my ($self,$node)=@_;
    my $fsfile = $self->start_file;
    return [
        map [ $_,$fsfile ], TreexUtils::AGetEParentsC($node)
    ];
  }
}
#################################################
{
  package PMLTQ::Relation::Treex::AEChildCIterator;
  use strict;
  use base qw(PMLTQ::Relation::SimpleListIterator);
  use PMLTQ::Relation {
      name => 'echildC',
      reversed_relation => 'implementation:eparentC',
      start_node_type => 'a-node',
      target_node_type => 'a-node',
      iterator_class => __PACKAGE__,
      iterator_weight => 5,
      test_code => q( grep($_ == $start, TreexUtils::AGetEParentsC($end)) ? 1 : 0 ),
  };
  sub get_node_list  {
    my ($self,$node)=@_;
    my $type = $node->type->get_base_type_name;
    my $fsfile = $self->start_file;
    return [
        map [ $_,$fsfile ], TreexUtils::AGetEChildrenC($node)
    ];
  }
}
##################################################
{
  package PMLTQ::Relation::Treex::AEParentIterator;
  use strict;
  use base qw(PMLTQ::Relation::SimpleListIterator);
  use PMLTQ::Relation {
      name => 'eparent',
      reversed_relation => 'implementation:echild',
      start_node_type => 'a-node',
      target_node_type => 'a-node',
      iterator_class => __PACKAGE__,
      test_code => q(grep($_ == $end, TreexUtils::AGetEParents($start)) ? 1 : 0),
  };
  sub get_node_list  {
    my ($self,$node)=@_;
    my $fsfile = $self->start_file;
    return [
        map [ $_,$fsfile ], TreexUtils::AGetEParents($node)
    ];
  }
}
#################################################
{
  package PMLTQ::Relation::Treex::TEParentIterator;
  use strict;
  use base qw(PMLTQ::Relation::SimpleListIterator);
  use PMLTQ::Relation {
      name => 'eparent',
      reversed_relation => 'implementation:echild',
      start_node_type => 't-node',
      target_node_type => 't-node',
      iterator_class => __PACKAGE__,
      iterator_weight => 2,
      test_code => q( grep($_ == $end, TreexUtils::TGetEParents($start)) ? 1 : 0 ),
  };
  sub get_node_list  {
    my ($self,$node)=@_;
    my $type = $node->type->get_base_type_name;
    my $fsfile = $self->start_file;
    return [
      map [ $_,$fsfile ], TreexUtils::TGetEParents($node)
    ];
  }
}
#################################################
{
  package PMLTQ::Relation::Treex::AEChildIterator;
  use strict;
  use base qw(PMLTQ::Relation::SimpleListIterator);
  use PMLTQ::Relation {
      name => 'echild',
      reversed_relation => 'implementation:eparent',
      start_node_type => 'a-node',
      target_node_type => 'a-node',
      iterator_class => __PACKAGE__,
      iterator_weight => 5,
      test_code => q( grep($_ == $start, TreexUtils::AGetEParents($end)) ? 1 : 0 ),
  };
  sub get_node_list  {
    my ($self,$node)=@_;
    my $type = $node->type->get_base_type_name;
    my $fsfile = $self->start_file;
    return [
        map [ $_,$fsfile ], TreexUtils::AGetEChildren($node)
    ];
  }
}
#################################################
{
  package PMLTQ::Relation::Treex::TEChildIterator;
  use strict;
  use base qw(PMLTQ::Relation::SimpleListIterator);
  use PMLTQ::Relation {
      name => 'echild',
      reversed_relation => 'implementation:eparent',
      start_node_type => 't-node',
      target_node_type => 't-node',
      iterator_class => __PACKAGE__,
      iterator_weight => 5,
      test_code => q( grep($_ == $start, TreexUtils::TGetEParents($end)) ? 1 : 0 ),
  };
  sub get_node_list  {
    my ($self,$node)=@_;
    my $type = $node->type->get_base_type_name;
    my $fsfile = $self->start_file;
    return [
      map [ $_,$fsfile ], TreexUtils::TGetEChildren($node)
    ];
  }
}


1;
__END__

=head1 NAME

Treex - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex,

Blah blah blah.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
