#pragma once
#import "CoolWearPolicy.h"

// Fields from the supplied K6 parser and command headers. Missing or malformed
// settings never become default "off" values. This is device configuration,
// not physiological data or clinical reminders.
static inline NSNumber *CoolWearReminderMinutes(id hour, id minute) {
    NSNumber *h = CoolWearUnsigned(hour, 24), *m = CoolWearUnsigned(minute, 59);
    return h && m && (h.integerValue < 24 || m.integerValue == 0) ? @(h.integerValue * 60 + m.integerValue) : nil;
}
static inline NSArray *CoolWearReminderDays(NSUInteger mask) {
    NSMutableArray *days = [NSMutableArray array];
    if (mask & 128) for (NSUInteger day = 1; day <= 7; day++)
        if (mask & (1 << (day % 7))) [days addObject:@(day)];
    return days;
}
static inline NSNumber *CoolWearReminderMask(id days) {
    if (![days isKindOfClass:NSArray.class] || [days count] > 7) return nil;
    NSUInteger mask = 0;
    for (id day in days) {
        NSNumber *n = CoolWearUnsigned(day, 7);
        if (!n || n.integerValue < 1 || (mask & (1 << (n.integerValue % 7)))) return nil;
        mask |= 1 << (n.integerValue % 7);
    }
    return @(mask ? mask | 128 : 127);
}
static inline NSDictionary *CoolWearReminderSnapshot(NSInteger type, id raw) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    if (type == 123) {
        NSNumber *on = CoolWearUnsigned(raw[@"onoff"], 1);
        return on ? @{@"enabled": @(on.boolValue)} : nil;
    }
    if (type == 114 || type == 126) {
        NSNumber *on = CoolWearUnsigned(raw[type == 114 ? @"isOpen" : @"onoff"], 1);
        NSNumber *start = CoolWearReminderMinutes(raw[@"startHour"], raw[@"startMin"]);
        NSNumber *end = CoolWearReminderMinutes(raw[@"endHour"], raw[@"endMin"]);
        if (!on || !start || !end || start.integerValue == 1440) return nil;
        NSMutableDictionary *value = [@{@"id": type == 114 ? @"sedentary" : @"drink",
            @"label": type == 114 ? @"久坐提醒" : @"喝水提醒", @"enabled": @(on.boolValue),
            @"startMinutes": start, @"endMinutes": end} mutableCopy];
        if (type == 114) {
            NSNumber *repeat = CoolWearUnsigned(raw[@"week_repeat"], 255), *noon = CoolWearUnsigned(raw[@"noon_onoff"], 1);
            if (!repeat || !noon) return nil;
            value[@"repeatMask"] = repeat;
            value[@"noonOff"] = noon;
        } else {
            NSNumber *interval = CoolWearUnsigned(raw[@"interval"], 3);
            if (!interval) return nil;
            NSArray *intervals = @[@30, @60, @120, @180];
            value[@"intervalMinutes"] = intervals[interval.integerValue];
            value[@"supportedIntervals"] = intervals;
        }
        return value;
    }
    if (type == 106) {
        id rows = raw[@"alarm_infos"];
        if (![rows isKindOfClass:NSArray.class] || [rows count] > 32) return nil;
        NSMutableArray *items = [NSMutableArray array];
        for (id row in rows) {
            if (![row isKindOfClass:NSDictionary.class]) return nil;
            NSNumber *repeat = CoolWearUnsigned(row[@"repeatDay"], 255), *on = CoolWearUnsigned(row[@"status"], 1);
            NSNumber *alarmType = CoolWearUnsigned(row[@"alarmType"], 0);
            NSNumber *time = CoolWearReminderMinutes(row[@"hour"], row[@"min"]);
            id name = row[@"name"];
            if (!alarmType || !repeat || !on || !time || time.integerValue >= 1440 || ![name isKindOfClass:NSString.class] || [name length] != 0) return nil;
            [items addObject:@{@"id": @(items.count).stringValue, @"hour": @(time.integerValue / 60),
                @"minute": @(time.integerValue % 60), @"enabled": @(on.boolValue), @"label": name,
                @"repeatDays": CoolWearReminderDays(repeat.unsignedIntegerValue), @"repeatMask": repeat}];
        }
        return @{@"items": items, @"supportsNames": @NO};
    }
    return nil;
}
static inline NSDictionary *CoolWearReminderChange(NSInteger type, NSDictionary *snapshot, NSDictionary *values) {
    id enabled = values[@"enabled"];
    if (![enabled isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID()) return nil;
    NSMutableDictionary *next = [snapshot mutableCopy];
    next[@"enabled"] = enabled;
    if (type == 114 || type == 126) {
        NSNumber *start = CoolWearUnsigned(values[@"startMinutes"], 1439), *end = CoolWearUnsigned(values[@"endMinutes"], 1440);
        if (!start || !end || ([enabled boolValue] && [start isEqual:end])) return nil;
        next[@"startMinutes"] = start; next[@"endMinutes"] = end;
        if (type == 126) {
            NSNumber *interval = CoolWearUnsigned(values[@"intervalMinutes"], 180);
            if (!interval || ![snapshot[@"supportedIntervals"] containsObject:interval]) return nil;
            next[@"intervalMinutes"] = interval;
        }
    }
    return next;
}
static inline NSDictionary *CoolWearAlarmChange(NSDictionary *snapshot, NSDictionary *values) {
    NSMutableArray *items = [snapshot[@"items"] mutableCopy];
    NSString *operation = values[@"operation"], *identifier = values[@"id"];
    BOOL add = [operation isEqual:@"add"], remove = [operation isEqual:@"delete"];
    if (!add && !remove && ![operation isEqual:@"update"]) return nil;
    NSUInteger index = NSNotFound;
    for (NSUInteger i = 0; i < items.count; i++) if ([items[i][@"id"] isEqual:identifier]) index = i;
    if (!add && index == NSNotFound) return nil;
    if (remove) [items removeObjectAtIndex:index];
    else {
        NSNumber *time = CoolWearReminderMinutes(values[@"hour"], values[@"minute"]), *mask = CoolWearReminderMask(values[@"repeatDays"]);
        id enabled = values[@"enabled"], label = values[@"label"];
        if (!time || time.integerValue >= 1440 || !mask || ![label isKindOfClass:NSString.class] ||
            [label length] != 0 ||
            ![enabled isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID() ||
            (add && items.count >= 32)) return nil;
        NSDictionary *item = @{@"hour": values[@"hour"], @"minute": values[@"minute"], @"enabled": enabled,
            @"label": label, @"repeatDays": values[@"repeatDays"], @"repeatMask": mask};
        if (add) [items addObject:item]; else items[index] = item;
    }
    for (NSUInteger i = 0; i < items.count; i++) {
        NSMutableDictionary *item = [items[i] mutableCopy]; item[@"id"] = @(i).stringValue; items[i] = item;
    }
    return @{@"items": items, @"supportsNames": @NO};
}
