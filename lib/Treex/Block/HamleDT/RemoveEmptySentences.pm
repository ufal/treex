package Treex::Block::HamleDT::RemoveEmptySentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
	my ( $self, $bundle ) = @_;
	my @zones = $bundle->get_all_zones();
	my $delete_zone = 0;
	foreach my $z (@zones) {
		my $sentence = $z->sentence;
		chomp $sentence;
		$sentence =~ s/\s+/ /g;
		$sentence =~ s/(^\s+|\s+$)//;
		if ($sentence =~ /^$/) {
			$delete_zone = 1;
			last;
		}
	}
	if ($delete_zone) {
		$bundle->remove();
	}	
}

1;

__END__