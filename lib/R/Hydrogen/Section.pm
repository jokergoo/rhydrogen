# this is the basic unit 
package R::Hydrogen::Section;
use R::Hydrogen::Format;
use English;
use Data::Dumper;
use strict;

sub new {
	my $class = shift;

	my $self = {name => shift(@_),
	            lines => [],
	            tree => {},
	            tex => "",
	            is_example => 0,};

	bless $self, $class;
	return $self;
}

sub add_line {
	my $self = shift;
	my $newline = shift;

	push(@{$self->{lines}}, $newline);
	return($self);
}


sub parse {
	my $self = shift;
	
	# for(my $i = $#{$self->{lines}}; $i >= 0; $i --) {
	# 	if($self->{lines}->[$i] =~/^\s*$/) {
	# 		pop(@{$self->{lines}});
	# 	} else {
	# 		last;
	# 	}
	# }

	$self->convert_to_tree()->format();
# print Dumper $self;
	return $self;
}

# convert the comment to a comment tree (only one level)
# 'content' is converted from arrays to hash, but we use prefix to keep the original order
#
# here we only assume there are following types of text in comment:
# - simple paragraph
# - a list without name
# - a list with name
# - code chunk
#
sub convert_to_tree {
	my $self = shift;

	my $lines_ref = $self->{lines};
	
	my $dl = [];
	for my $i ("a".."z") {
		for my $j ("a".."z") {
			push(@$dl, "$i$j");
		}
	}
	
	my $tree;
	for(my $i = 0; $i < scalar(@$lines_ref); $i ++) {
		if($lines_ref->[$i] eq "") {
			next;
		}
		
		my $h;
		if($self->{is_example}) {
			($h, $i) = read_paragraph($lines_ref, $i);
			$tree->{shift(@$dl)."_paragraph"} = $h;
		} else {
			if($lines_ref->[$i] =~/^-\s/) {
				($h, $i) = read_item($lines_ref, $i);
				$h =~s/^\s+|\s+$//sg;
				$tree->{shift(@$dl)."_item"} = $h;
			} elsif($lines_ref->[$i] =~/^-\S+\s/) {
				($h, $i) = read_named_item($lines_ref, $i);
				$h =~s/^\s+|\s+$//sg;
				$tree->{shift(@$dl)."_named_item"} = $h;
			} elsif($lines_ref->[$i] =~/^\s+\S/ and is_code_block($lines_ref, $i)) {
				($h, $i) = read_code_block($lines_ref, $i);
				$h =~s/\s+$//sg;
				$tree->{shift(@$dl)."_code_block"} = $h;
			} elsif($lines_ref->[$i] =~/\S/) {
				($h, $i) = read_paragraph($lines_ref, $i);
				$h =~s/^\s+|\s+$//sg;
				$tree->{shift(@$dl)."_paragraph"} = $h;
			}
		}
	}

	$self->{tree} = $tree;
	return $self;
}


sub format {
	my $self = shift;
	
	my $str;
	foreach my $k (sort keys %{$self->{tree}}) {
		my $v = $self->{tree}->{$k};
		if($self->{is_example}) {
			$str .= "$v\n";
		} elsif($k =~/_paragraph/) {
			$str .= inline_format($v)."\n\n";
		} elsif($k =~/_named_item/) {
			$str .= "\\describe{\n";
			for(my $i = 0; $i < scalar(@{$v->{name}}); $i ++) {
				$str .= "  \\item{".inline_format($v->{name}->[$i])."}{".inline_format($v->{value}->[$i])."}\n";
			}
			$str .= "}\n\n";
		} elsif($k =~/_item/) {
			$str .= "\\itemize{\n";
			for(my $i = 0; $i < scalar(@{$v}); $i ++) {
				$str .= "  \\item ".inline_format($v->[$i])."\n";
			}
			$str .= "}\n\n";
		} elsif($k =~/_code_block/) {
			$str .= "  \\preformatted{\n";
			$v =~s/\{/\\{/g;
			$v =~s/\}/\\}/g;
			$str .= $v;
			$str .= "  }\n\n";
		}
	}

	$str =~s/^\s+|\s+$//sg;

	$self->{tex} = $str;
	return($self);
}


my $PREDEFINED_SECTION_NAME = {
	title => 1,
	alias => 1,
	docType => 1,
	name => 1,
	description => 1,
	usage => 1,
	arguments => 1,
	details => 1,
	references => 1,
	author => 1,
	value => 1,
	seealso => 1,
	examples => 1,

};

sub string {
	my $self = shift;

	if($self->{name} eq "name" || $self->{name} eq "alias" || $self->{name} eq "docType") {
		$self->{tex} =~s/^\s+|\s+$//sg;
		$self->{tex} =~s/%/\\%/g;
		if($self->{name} eq "name" and $self->{tex} =~/<-/) {
			"\\$self->{name}"."{".filter_str($self->{tex})."}\n";
		} else {
			"\\$self->{name}"."{$self->{tex}}\n";
		}
	} elsif(defined($PREDEFINED_SECTION_NAME->{$self->{name}})) {
		if($self->{name} eq "usage") {
			if($self->{tex} =~/%/ && $self->{tex} =~/\(/) {
				# print $self->{tex}, "\n============\n";
			} else {
				$self->{tex} =~s/%/\\%/g;
			}
		}
		"\\$self->{name}"."{\n$self->{tex}\n}\n";
	} else {
		"\\section{".ucfirst($self->{name})."}{\n$self->{tex}}\n";
	}
}

sub filter_str {
	my $str = shift;

	$str =~s/\+/add/g;
	$str =~s/\[/Extract/g;
	$str =~s/\$<-/Assign/g;
	$str =~s/<-/Assign/g;
	$str =~s/\$/Subset/g;
	$str =~s/^\./Dot./g;
	$str =~s/^\%/pct_/g;
	$str =~s/\%$/_pct/g;

	return $str;
}


1;
